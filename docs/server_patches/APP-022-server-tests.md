# APP-022: Server Tests for Atomic Writes + Publish Gate

## Purpose

APP-019 (atomic writes) and APP-020 (Archive.org reachability gate) introduce
two critical invariants. Without tests, these invariants can silently regress
the next time someone edits the publish path. This document provides reference
test implementations that Larry can drop into `tests/` on the Intel Mac.

## Test 1: `tests/test_atomic_writes.py`

Verifies that `atomic_write_text` never exposes partial content to a concurrent
reader.

```python
"""Verify atomic_write_text never exposes partial content.

A reader thread tails a file in a tight loop while a writer thread
runs atomic_write_text repeatedly. Every read must return either the
complete old content or the complete new content — never a mix.
"""
import os
import threading
import time
from pathlib import Path

# Adjust this import to match where atomic_write_text lands:
# from main import atomic_write_text
# — or —
# from utils import atomic_write_text


def atomic_write_text(path: Path, text: str, *, encoding: str = "utf-8") -> None:
    """Inline copy for self-contained testing. Replace with the real import."""
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(text, encoding=encoding)
    os.replace(tmp, path)


CONTENT_A = "A" * 1_000_000  # 1 MB of 'A's
CONTENT_B = "B" * 1_000_000  # 1 MB of 'B's
WRITE_CYCLES = 200
READ_CYCLES = 2000


def test_concurrent_reader_never_sees_partial(tmp_path):
    """Reader must always see either all-A or all-B, never a mix."""
    target = tmp_path / "feed.xml"
    target.write_text(CONTENT_A)

    violations = []

    def writer():
        for i in range(WRITE_CYCLES):
            content = CONTENT_A if i % 2 == 0 else CONTENT_B
            atomic_write_text(target, content)

    def reader():
        for _ in range(READ_CYCLES):
            try:
                data = target.read_text()
                if data and data[0] in ("A", "B"):
                    expected_char = data[0]
                    if not all(c == expected_char for c in data):
                        violations.append(f"Mixed content: starts with {expected_char} but has other chars")
                elif data:
                    violations.append(f"Unexpected content start: {data[:20]}")
            except FileNotFoundError:
                pass  # Acceptable during rename window on some filesystems
            except Exception as e:
                violations.append(f"Read error: {e}")

    writer_thread = threading.Thread(target=writer)
    reader_thread = threading.Thread(target=reader)

    writer_thread.start()
    reader_thread.start()

    writer_thread.join()
    reader_thread.join()

    assert not violations, f"Partial reads detected: {violations[:5]}"


def test_atomic_write_replaces_content(tmp_path):
    """Basic correctness: content is fully replaced after write."""
    target = tmp_path / "test.json"
    target.write_text("original")

    atomic_write_text(target, "replaced")

    assert target.read_text() == "replaced"


def test_atomic_write_creates_file(tmp_path):
    """atomic_write_text works even if the target doesn't exist yet."""
    target = tmp_path / "new_file.json"

    atomic_write_text(target, '{"key": "value"}')

    assert target.read_text() == '{"key": "value"}'
    # .tmp file should not linger
    assert not target.with_suffix(".json.tmp").exists()
```

## Test 2: `tests/test_publish_gate.py`

Verifies that `<item>` insertion is gated on Archive.org HEAD returning 200.

```python
"""Verify the Archive.org reachability gate defers <item> until HEAD=200.

Mocks ia.upload() and HTTP HEAD responses. The gate must:
- NOT insert <item> when HEAD returns 404 (pending state)
- Insert <item> only when HEAD returns 200 (success state)
"""
from unittest.mock import patch, MagicMock
import pytest

# Adjust import path to match your project structure:
# from main import wait_for_archive_reachability


def wait_for_archive_reachability(url: str, max_retries: int = 6) -> str:
    """Inline copy for self-contained testing. Replace with the real import."""
    import time
    import requests

    delay = 2
    for attempt in range(max_retries):
        try:
            resp = requests.head(url, timeout=10, allow_redirects=True)
            if resp.status_code in (200, 206):
                return "success"
        except Exception:
            pass
        time.sleep(delay)
        delay *= 2
    return "pending"


class TestPublishGate:
    """Tests for Archive.org reachability gating."""

    TEST_URL = "https://archive.org/download/test-identifier/test-audio.mp3"

    @patch("requests.head")
    @patch("time.sleep")  # Skip actual waits in tests
    def test_returns_success_on_immediate_200(self, mock_sleep, mock_head):
        """If HEAD returns 200 on first try, result is 'success'."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_head.return_value = mock_response

        result = wait_for_archive_reachability(self.TEST_URL, max_retries=6)

        assert result == "success"
        assert mock_head.call_count == 1

    @patch("requests.head")
    @patch("time.sleep")
    def test_returns_success_after_retries(self, mock_sleep, mock_head):
        """First 3 calls return 404, 4th returns 200 → 'success'."""
        mock_404 = MagicMock()
        mock_404.status_code = 404
        mock_200 = MagicMock()
        mock_200.status_code = 200

        mock_head.side_effect = [mock_404, mock_404, mock_404, mock_200]

        result = wait_for_archive_reachability(self.TEST_URL, max_retries=6)

        assert result == "success"
        assert mock_head.call_count == 4

    @patch("requests.head")
    @patch("time.sleep")
    def test_returns_pending_on_timeout(self, mock_sleep, mock_head):
        """All retries return 404 → 'pending'."""
        mock_404 = MagicMock()
        mock_404.status_code = 404
        mock_head.return_value = mock_404

        result = wait_for_archive_reachability(self.TEST_URL, max_retries=6)

        assert result == "pending"
        assert mock_head.call_count == 6

    @patch("requests.head")
    @patch("time.sleep")
    def test_handles_206_partial_content(self, mock_sleep, mock_head):
        """Archive.org sometimes returns 206 for range-capable files."""
        mock_206 = MagicMock()
        mock_206.status_code = 206
        mock_head.return_value = mock_206

        result = wait_for_archive_reachability(self.TEST_URL, max_retries=6)

        assert result == "success"

    @patch("requests.head")
    @patch("time.sleep")
    def test_handles_network_errors_gracefully(self, mock_sleep, mock_head):
        """Network errors during HEAD don't crash — treated as retryable."""
        import requests as req

        mock_200 = MagicMock()
        mock_200.status_code = 200

        mock_head.side_effect = [
            req.ConnectionError("refused"),
            req.Timeout("timed out"),
            mock_200,
        ]

        result = wait_for_archive_reachability(self.TEST_URL, max_retries=6)

        assert result == "success"
        assert mock_head.call_count == 3
```

## Running the Tests

On the Intel Mac (M4 cannot run this Python):

```bash
cd /Users/larryseyer/JTFNews
./venv/bin/python -m pytest tests/test_atomic_writes.py tests/test_publish_gate.py -v
```

### Prerequisites

```bash
# Ensure pytest is available:
./venv/bin/pip install pytest

# If test_publish_gate needs requests (it should already be installed):
./venv/bin/pip install requests
```

## Application Instructions

1. Create `tests/` directory if it doesn't exist: `mkdir -p tests`
2. Copy the test files above into `tests/test_atomic_writes.py` and
   `tests/test_publish_gate.py`.
3. Update the import lines to point to the real `atomic_write_text` and
   `wait_for_archive_reachability` functions (removing the inline copies).
4. Run: `./venv/bin/python -m pytest tests/ -v`
5. Once passing: `./bu.sh "APP-022: add server tests for atomic writes + publish gate"`

## Notes

- The inline function copies in each test file make the tests self-contained
  and runnable even before APP-019/020 are applied. Once the real functions
  exist in main.py or utils.py, replace the inline copies with imports.
- The concurrent-reader test (`test_atomic_writes.py`) uses 1 MB payloads and
  200 write cycles to make partial reads likely if atomicity breaks.
