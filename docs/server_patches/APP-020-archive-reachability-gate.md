# APP-020: Archive.org Reachability Gate Before Publishing `<item>`

## The Race Condition

Today, `upload_to_archive_org` (approx main.py line 6776-6782) returns a
constructed Archive.org URL the instant `ia.upload()` acknowledges the upload.
However, Archive.org takes **seconds to minutes** to make the file publicly
retrievable via HTTP. During that propagation window, `update_podcast_feeds`
inserts an `<item>` into `podcast.xml` with an `<enclosure>` URL that returns
**404** to any client attempting to download it.

For the iOS app, this means the Digest tab can show an episode row whose audio
link is dead — the user taps play, gets silence or an error, and loses trust
in the feed. For a Truth-first product, publishing a claim of availability
before availability exists is a factual misrepresentation.

## Proposed Fix: HEAD Poll with Exponential Backoff

After `ia.upload()` returns, poll the constructed URL with HTTP HEAD requests
using exponential backoff before declaring the upload successful.

```python
import time
import requests

def wait_for_archive_reachability(url: str, max_retries: int = 6) -> str:
    """Poll Archive.org URL until HEAD returns 200/206, or timeout.

    Backoff schedule: 2s, 4s, 8s, 16s, 32s, 64s (total ~126s, cap ~2 min).
    Returns "success" if reachable, "pending" if timed out.
    """
    delay = 2
    for attempt in range(max_retries):
        try:
            resp = requests.head(url, timeout=10, allow_redirects=True)
            if resp.status_code in (200, 206):
                return "success"
        except requests.RequestException:
            pass  # network blip — retry
        time.sleep(delay)
        delay *= 2
    return "pending"
```

### Integration with `upload_to_archive_org`

#### Before (approx line 6776-6782):
```python
def upload_to_archive_org(audio_path, identifier, title):
    # ... ia.upload() call ...
    url = f"https://archive.org/download/{identifier}/{audio_path.name}"
    return {"status": "success", "url": url}
```

#### After:
```python
def upload_to_archive_org(audio_path, identifier, title):
    # ... ia.upload() call ...
    url = f"https://archive.org/download/{identifier}/{audio_path.name}"
    reachability = wait_for_archive_reachability(url)
    return {"status": reachability, "url": url}
```

### Integration with `update_podcast_feeds`

The feed-writing code must respect the status:

```python
upload_result = upload_to_archive_org(audio_path, identifier, title)

if upload_result["status"] == "success":
    # Insert <item> into podcast.xml with the verified URL
    insert_podcast_item(upload_result["url"], ...)
elif upload_result["status"] == "pending":
    # Do NOT insert <item> this cycle
    logger.warning(f"Archive.org not yet reachable for {identifier}; "
                   f"deferring <item> insertion to next cycle")
```

On the next `check_midnight_archive` tick, the upload should be re-attempted
or the reachability re-checked. The episode will appear in the feed once — and
only once — the audio is actually downloadable.

### `monitor.json` Field

Add `upload_status` to the `daily_digest` section of `monitor.json`:

```json
{
  "daily_digest": {
    "podcast_updated": true,
    "upload_status": "success",
    ...
  }
}
```

Values: `"success"` (HEAD returned 200, item published) or `"pending"` (HEAD
timed out, item deferred). This gives the iOS app's monitor.json cross-check
(APP-010) visibility into whether the audio is actually available.

## Application Instructions

1. **On the Intel Mac** (`/Users/larryseyer/JTFNews`):
2. Stop or pause main.py's publish loop.
3. Add `wait_for_archive_reachability` function (after imports or in utils.py).
4. Modify `upload_to_archive_org` to call the reachability check before returning.
5. Modify `update_podcast_feeds` to branch on `status == "success"` vs `"pending"`.
6. Add `upload_status` to the `monitor.json` output in the daily_digest section.
7. Review: `git diff main.py`
8. Commit: `./bu.sh "APP-020: gate podcast.xml items on Archive.org HEAD reachability"`
9. Restart main.py.

## Verification

```bash
# During the next daily publish cycle, watch the log:
tail -f jtf.log | grep -i "archive\|reachab\|pending"

# After publish, confirm the audio URL works:
curl -sI "$(curl -s https://jtfnews.org/podcast.xml | grep -oP 'url="[^"]*archive.org[^"]*"' | head -1 | tr -d 'url="')" | head -5
# Expected: HTTP/1.1 200 OK (or 206 Partial Content)
```

If the upload status is `"pending"`, the episode should NOT appear in
podcast.xml until the next cycle successfully confirms HEAD 200.

## Scope Note

Ralph cannot edit main.py directly. Larry applies this patch via Edit +
`./bu.sh "APP-020: gate podcast.xml items on Archive.org HEAD reachability"`
on the Intel Mac.
