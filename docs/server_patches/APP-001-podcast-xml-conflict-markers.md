# APP-001: Strip Git Conflict Markers from Production podcast.xml

## What Was Observed

The published feed at `https://jtfnews.org/podcast.xml` contains three unresolved git merge conflict markers:

| Line | Text |
|------|------|
| 1110 | `<<<<<<< Updated upstream` |
| 1204 | `=======` |
| 1205 | `>>>>>>> Stashed changes` |

Apple's `XMLParser` aborts at **line 1110, column 2** with:

> StartTag: invalid element name

Everything after line 1110 is lost to the iOS/macOS app. The Digest tab shows only episodes through **April 8** (the last `<item>` that closes before line 1110), while the server's `monitor.json` reports through April 13.

### Additional data issues (flagged for follow-up, not fixed here)

- **April 12 is missing entirely** from the feed — no `<item>` for that date exists.
- **April 13 has episode number 1** (duplicate of the very first episode), likely a counter reset during the stash conflict.

These are content/data issues requiring investigation of the episode-numbering logic in `main.py`, not a mechanical fix like the markers.

## Root-Cause Hypothesis

A `git stash pop` (or `git merge`) left conflict markers in `jtfnews.org/podcast.xml`. The file was then published to GitHub Pages via `main.py`'s GitHub API push path, which does not run `bu.sh` and therefore bypassed any pre-commit checks or human review. The markers were committed and pushed as literal XML content.

## Safe Remediation Recipe (Intel Mac)

Run these steps on the **2012 Intel Mac** at `/Users/larryseyer/JTFNews`.

### Step 1 — Pause the publish loop

Stop `main.py` or pause its publish cycle so it does not overwrite your fix mid-edit.

```bash
# If main.py is running in a tmux/screen session, Ctrl-C it
# or kill the process:
ps aux | grep main.py
kill <PID>
```

### Step 2 — Navigate to the repo

```bash
cd /Users/larryseyer/JTFNews
```

### Step 3 — Inspect the file on-disk

Check whether the markers are in the local working copy or only in the published (remote) copy:

```bash
grep -n '<<<<<<< \|=======\|>>>>>>> ' jtfnews.org/podcast.xml
```

- **If markers are present locally:** proceed to Step 4.
- **If markers are NOT local** (only on the published GitHub Pages copy): the local file is clean but a stale published version persists. A `./bu.sh` commit of the clean file will overwrite the remote. Skip the sed in Step 4 and go directly to Step 5.

### Step 4 — Remove the markers (if present locally)

Preview the changes first:

```bash
sed -e '/^<<<<<<< /d' -e '/^=======$/d' -e '/^>>>>>>> /d' jtfnews.org/podcast.xml | diff jtfnews.org/podcast.xml - | head -40
```

If the diff looks correct (only the three marker lines removed, all `<item>` content preserved):

```bash
sed -i '' -e '/^<<<<<<< /d' -e '/^=======$/d' -e '/^>>>>>>> /d' jtfnews.org/podcast.xml
```

### Step 5 — Verify episode preservation

Confirm the April 9, 10, 11, and 13 episodes survived:

```bash
grep -c '<item>' jtfnews.org/podcast.xml
grep '<title>' jtfnews.org/podcast.xml | tail -10
```

Note: **April 12 is expected to be missing** — that is a separate data issue, not caused by the markers.

### Step 6 — Commit via bu.sh

```bash
./bu.sh "APP-001: remove unresolved merge markers from published podcast.xml"
```

### Step 7 — Restart main.py

```bash
cd /Users/larryseyer/JTFNews
./venv/bin/python main.py &
```

(Or restart it in your preferred tmux/screen session.)

## Follow-Up Investigations

These are **not** part of this fix but should be tracked:

1. **Missing April 12 episode** — investigate whether `main.py` failed to generate the item, or whether it was lost during the stash conflict.
2. **Duplicate episode number 1 on April 13** — check the episode counter logic in `main.py` for reset-on-conflict or off-by-one behavior.

## Structural Prevention

This APP-001 patch is a **one-time cleanup**. The structural fixes that prevent this class of accident from recurring are:

- **APP-019 (Atomic Writes)** — ensures `podcast.xml` is written atomically (write-to-temp + rename) so a crash or conflict cannot leave a half-written file on disk.
- **APP-021 (Single-Commit Push)** — ensures the GitHub API push path in `main.py` mirrors the safety of `bu.sh`, preventing unreviewed content from reaching production.

Until APP-019 and APP-021 are applied, the manual `bu.sh` workflow remains the safest publish path.
