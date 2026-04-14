# APP-023: Publish Invariants

This document is intended to be placed at:
`/Volumes/MacLive/Users/larryseyer/JTFNews/docs/publish_invariants.md`

Larry should copy the content below into that file and commit via:
`./bu.sh "APP-023: add publish invariants document"`

---

# Publish Invariants

These three invariants govern every code path that publishes content to
jtfnews.org. They exist because JTF News's brand promise — "Just the Facts" —
extends beyond the stories themselves to the delivery mechanism: if the feed
is half-written, if an audio link is dead, if a consumer sees a mixed state
between two publish cycles, we have presented something other than the facts.

Every commit that touches the publish path must preserve all three invariants.

## Invariant 1: Atomic File Replacement

> Every published file is atomically replaced. No reader — whether a CDN
> revalidation, a browser fetch, or an iOS URLSession — ever observes
> partial content.

**Implementation:** `atomic_write_text()` writes to a `.tmp` sibling, then
calls `os.replace()` (a single POSIX `rename(2)` syscall).

**Applies to:** `podcast.xml`, `stories.json`, `corrections.json`,
`monitor.json`, `archive/index.json`, and any future published file.

**Reference:** APP-019

## Invariant 2: Enclosure Reachability

> `podcast.xml` never contains an `<item>` whose `<enclosure>` URL is not
> HTTP HEAD-200 (or 206) reachable.

**Implementation:** `wait_for_archive_reachability()` polls the Archive.org
URL with exponential backoff after `ia.upload()` acknowledges. If HEAD does
not return 200/206 within the timeout, the upload status is `"pending"` and
the `<item>` is **not inserted** into `podcast.xml` this cycle. The next
scheduled tick re-attempts.

**Applies to:** Every `<item>` insertion in `update_podcast_feeds`.

**Reference:** APP-020

## Invariant 3: Atomic Publish Cycle

> A publish cycle flips the GitHub Pages origin ref atomically via a single
> commit. Consumers never observe a mixed state between two cycles.

**Implementation:** `atomic_push_to_ghpages()` uses the GitHub Git Data API
to create blobs, build a tree, create a commit, and update the ref in a
single operation. The ref update is the only point where public-facing
content changes.

**Applies to:** `push_to_ghpages` and any future publish-to-origin code path.

**Reference:** APP-021

---

## Before You Change Publish Code

Use this checklist before merging any change to `main.py` that touches the
publish path:

- [ ] **Atomic writes:** Does the change write any file that consumers read?
  If yes, is it using `atomic_write_text()`? A raw `.write_text()` or
  `open(..., 'w')` breaks Invariant 1.

- [ ] **Enclosure reachability:** Does the change insert an `<item>` into
  `podcast.xml`? If yes, is the `<enclosure>` URL confirmed reachable via
  HEAD poll? Inserting before confirmation breaks Invariant 2.

- [ ] **Single-commit push:** Does the change modify `push_to_ghpages` or
  add a new push path? If yes, does it still use the Git Data API for a
  single atomic commit? Per-file PUTs break Invariant 3.

- [ ] **Tests pass:** Do `test_atomic_writes.py` and `test_publish_gate.py`
  still pass? Run: `./venv/bin/python -m pytest tests/ -v`

- [ ] **Monitor field:** If the change adds a new publish artifact or
  changes timing, does `monitor.json` reflect the new state? The iOS app
  cross-checks `monitor.json` against feed content (APP-010).

---

## Incident Reference

These invariants were established after the April 2026 incident where:

1. A `git stash pop` left unresolved conflict markers in `podcast.xml`,
   which was then published via the GitHub API push path (APP-001).
2. The iOS app's XML parser silently returned a partial episode list,
   showing April 8 as the latest episode while the server had through
   April 13 (APP-002, APP-003, APP-004).
3. The app had no mechanism to detect or recover from stale data (APP-005
   through APP-010, APP-016, APP-017).

The full story sweep (APP-001 through APP-023) addressed both the immediate
symptoms and the structural causes.
