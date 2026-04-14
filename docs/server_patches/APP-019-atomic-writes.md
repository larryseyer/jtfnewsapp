# APP-019: Atomic Write Helper + Every Publish Call Site

## Problem

Production `main.py` writes published files (`podcast.xml`, `stories.json`,
`corrections.json`, `monitor.json`, `archive/index.json`) in-place using
`.write_text(...)` or `open(..., 'w')`. A reader — Fastly revalidating, a
browser fetch, iOS `URLSession` — can observe a half-written file during the
write window. On a slow disk or a large file (podcast.xml is ~50 KB), that
window is measurable.

## Proposed Fix: `atomic_write_text` Helper

```python
import os
from pathlib import Path

def atomic_write_text(path: Path, text: str, *, encoding: str = "utf-8") -> None:
    """Write text to a file atomically via rename.

    Writes to a .tmp sibling first, then calls os.replace() which is
    atomic on POSIX (single rename syscall). Readers never see a
    partial file — they see either the old content or the new content.
    """
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(text, encoding=encoding)
    os.replace(tmp, path)
```

### Why `os.replace`?

`os.replace(src, dst)` is guaranteed atomic on POSIX — it maps to a single
`rename(2)` syscall. The filesystem ensures the directory entry flips in one
operation. Windows provides the same guarantee via `MoveFileEx` with
`MOVEFILE_REPLACE_EXISTING`. `os.rename()` would also work on Unix but fails
on Windows when the destination exists; `os.replace()` is cross-platform.

## Call Sites to Convert

**Note:** Line numbers are approximate from the April 2026 version of main.py.
Before editing, grep to confirm current locations:

```bash
cd /Users/larryseyer/JTFNews
grep -n 'write_text\|open(.*"w")' main.py
```

| File Written | Approx Line | Current Pattern |
|---|---|---|
| `podcast.xml` | ~6945 | `.write_text(xml_content)` |
| `stories.json` | ~3226 | `.write_text(json.dumps(...))` |
| `corrections.json` | ~4566 | `.write_text(json.dumps(...))` |
| `monitor.json` | ~7241 | `.write_text(json.dumps(...))` |
| `archive/index.json` | ~7599 | `.write_text(json.dumps(...))` |

## Worked Example (One Call Site)

### Before (`stories.json`, approx line 3226):
```python
stories_path = ghpages_dir / "stories.json"
stories_path.write_text(json.dumps(stories_payload, indent=2))
```

### After:
```python
stories_path = ghpages_dir / "stories.json"
atomic_write_text(stories_path, json.dumps(stories_payload, indent=2))
```

That's it per call site — a function-name change. The helper handles the
tmp-write + atomic replace.

## Where to Place the Helper

Add `atomic_write_text` near the top of `main.py` (after imports) or in a
small `utils.py` if you prefer separation. If using `utils.py`, add
`from utils import atomic_write_text` to main.py.

## Application Instructions

1. **On the Intel Mac** (`/Users/larryseyer/JTFNews`):
2. Stop or pause main.py's publish loop.
3. Grep for current write call sites: `grep -n 'write_text\|open(.*"w")' main.py`
4. Add the `atomic_write_text` function.
5. Replace each `.write_text(...)` call with `atomic_write_text(path, content)`.
6. Review the diff: `git diff main.py`
7. Commit via bu.sh: `./bu.sh "APP-019: atomic feed writes"`
8. Restart main.py.

## Verification

```bash
# Watch the log during the next publish cycle:
tail -f jtf.log

# Confirm readers see complete content (not truncated XML):
curl -s https://jtfnews.org/podcast.xml | head -2
# Expected: <?xml version="1.0"...  followed by <rss ...>

curl -s https://jtfnews.org/stories.json | python3 -c "import sys,json; json.load(sys.stdin); print('valid JSON')"
```

During a publish cycle, readers should never see a mid-write state (truncated
JSON, partial XML). The `.tmp` file is invisible to web-serving because GitHub
Pages only serves committed content — but the atomic pattern also protects
local readers (the Intel Mac's own scheduled tasks) from observing partial
writes.

## Scope Note

Ralph cannot edit main.py directly. Larry applies this patch via Edit +
`./bu.sh "APP-019: atomic feed writes"` on the Intel Mac.

This patch addresses the local-write atomicity layer. APP-021 (single-commit
GitHub Pages push) addresses the remote-publish atomicity layer. Together they
ensure consumers never observe partial content at any point in the pipeline.
