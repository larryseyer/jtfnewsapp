# APP-021: Single-Commit GitHub Pages Push via Git Data API

## Problem

`push_to_ghpages` (approx main.py line 7322-7401) issues **per-file HTTP
PUTs** via the GitHub Contents API. During a publish cycle, the GitHub Pages
origin sees multiple ref states as each file is pushed in sequence. Fastly
(GitHub Pages CDN) revalidates per-push, and consumers mid-cycle can fetch a
**mixed set** — for example, old `podcast.xml` paired with new `monitor.json`.

This is a Truth hazard: the app's cross-check logic (APP-010) compares
`monitor.json.last_date` against the newest episode in `podcast.xml`. If
`monitor.json` lands first with today's date but `podcast.xml` hasn't been
pushed yet, the cross-check fires a false mismatch banner.

## Proposed Fix: Git Data API (Tree + Commit + Ref Update)

The GitHub Git Data API lets you build an entire tree and commit it atomically.
The origin ref flips once; Fastly revalidates once; consumers see either the
fully-old or fully-new state.

### The 4-Step Recipe

1. **Create blobs** for each changed file:
   ```
   POST /repos/:owner/:repo/git/blobs
   { "content": "<base64>", "encoding": "base64" }
   → { "sha": "blob_sha" }
   ```

2. **Build a tree** referencing the new blobs + existing unchanged files:
   ```
   GET /repos/:owner/:repo/git/trees/main  (get current tree SHA)
   POST /repos/:owner/:repo/git/trees
   { "base_tree": "current_tree_sha",
     "tree": [
       { "path": "podcast.xml", "mode": "100644", "type": "blob", "sha": "blob1_sha" },
       { "path": "stories.json", "mode": "100644", "type": "blob", "sha": "blob2_sha" },
       ...
     ] }
   → { "sha": "new_tree_sha" }
   ```

3. **Create a commit** pointing to the new tree:
   ```
   POST /repos/:owner/:repo/git/commits
   { "message": "daily publish 2026-04-14",
     "tree": "new_tree_sha",
     "parents": ["current_commit_sha"] }
   → { "sha": "new_commit_sha" }
   ```

4. **Update the ref** atomically:
   ```
   PATCH /repos/:owner/:repo/git/refs/heads/main
   { "sha": "new_commit_sha" }
   ```

### Failure Handling

If any step (1-3) fails, the old ref is still intact — consumers continue to
see the previous publish. No half-published state is possible because the ref
update in step 4 is the only point where the public-facing content changes, and
it's a single atomic operation.

If step 4 fails (e.g., a concurrent push moved the ref), retry with a fresh
parent SHA. This is equivalent to a fast-forward merge race and is handled
gracefully by re-reading the current ref and retrying.

## Python Pseudo-Code

```python
import base64
import requests

GITHUB_API = "https://api.github.com"
OWNER = "larryseyer"
REPO = "larryseyer.github.io"  # or the actual repo name
HEADERS = {
    "Authorization": f"token {GITHUB_TOKEN}",
    "Accept": "application/vnd.github.v3+json",
}

def atomic_push_to_ghpages(changed_files: dict[str, bytes], commit_msg: str):
    """Push all changed files as a single atomic commit.

    changed_files: { "podcast.xml": b"<xml content>", "stories.json": b"..." }
    """
    # Step 0: Get current commit + tree SHA
    ref = requests.get(
        f"{GITHUB_API}/repos/{OWNER}/{REPO}/git/refs/heads/main",
        headers=HEADERS
    ).json()
    current_commit_sha = ref["object"]["sha"]

    commit = requests.get(
        f"{GITHUB_API}/repos/{OWNER}/{REPO}/git/commits/{current_commit_sha}",
        headers=HEADERS
    ).json()
    current_tree_sha = commit["tree"]["sha"]

    # Step 1: Create blobs
    tree_entries = []
    for path, content in changed_files.items():
        blob = requests.post(
            f"{GITHUB_API}/repos/{OWNER}/{REPO}/git/blobs",
            headers=HEADERS,
            json={"content": base64.b64encode(content).decode(), "encoding": "base64"}
        ).json()
        tree_entries.append({
            "path": path,
            "mode": "100644",
            "type": "blob",
            "sha": blob["sha"],
        })

    # Step 2: Build tree (base_tree keeps all unchanged files)
    new_tree = requests.post(
        f"{GITHUB_API}/repos/{OWNER}/{REPO}/git/trees",
        headers=HEADERS,
        json={"base_tree": current_tree_sha, "tree": tree_entries}
    ).json()

    # Step 3: Create commit
    new_commit = requests.post(
        f"{GITHUB_API}/repos/{OWNER}/{REPO}/git/commits",
        headers=HEADERS,
        json={
            "message": commit_msg,
            "tree": new_tree["sha"],
            "parents": [current_commit_sha],
        }
    ).json()

    # Step 4: Atomic ref update
    requests.patch(
        f"{GITHUB_API}/repos/{OWNER}/{REPO}/git/refs/heads/main",
        headers=HEADERS,
        json={"sha": new_commit["sha"]}
    )
```

### Replacing `push_to_ghpages`

The existing per-file PUT loop in `push_to_ghpages` (approx lines 7322-7401)
should be replaced with a call to `atomic_push_to_ghpages`. Collect all
files that would have been pushed individually into the `changed_files` dict,
then call once.

## Application Instructions

1. **On the Intel Mac** (`/Users/larryseyer/JTFNews`):
2. Stop or pause main.py's publish loop.
3. Add `atomic_push_to_ghpages` function (or replace the body of `push_to_ghpages`).
4. Update callers to pass all changed files as a single batch instead of one-by-one.
5. Review: `git diff main.py`
6. Commit: `./bu.sh "APP-021: atomic single-commit GitHub Pages publish"`
7. Restart main.py.

## Verification

```bash
# During the next publish cycle, watch GitHub for a single commit:
# (previously you'd see N commits in quick succession)
curl -s "https://api.github.com/repos/larryseyer/larryseyer.github.io/commits?per_page=5" \
  | python3 -c "import sys,json; [print(c['sha'][:8], c['commit']['message'][:60]) for c in json.load(sys.stdin)]"

# Confirm all files have the same commit timestamp (single atomic push):
# All should show the same SHA
```

## Scope Note

Ralph cannot edit main.py directly. Larry applies this patch via Edit +
`./bu.sh "APP-021: atomic single-commit GitHub Pages publish"` on the Intel Mac.

This patch addresses the **remote-publish atomicity layer**. APP-019 (atomic
local writes) addresses the **local-write atomicity layer**. Together they
ensure no consumer — whether reading from disk or from the CDN — ever observes
partial content.
