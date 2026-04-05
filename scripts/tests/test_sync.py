"""Unit tests for looperpowers_sync.py core logic.

Run: pytest scripts/tests/test_sync.py -v
"""
import json
import os
import sys
import tempfile
from datetime import datetime, timezone, timedelta
from pathlib import Path
from unittest.mock import patch, MagicMock

# Import the script module — we'll add a guard in the script so importing doesn't execute main()
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "Sources/Boop/Resources"))


class TestComputeCutoff:
    def test_uses_last_successful_sync_when_present(self):
        from looperpowers_sync import compute_cutoff
        last = "2026-03-20T10:00:00Z"
        status = {"last_successful_sync": last}
        cutoff = compute_cutoff(status, days_override=None)
        assert cutoff == datetime(2026, 3, 20, 10, 0, 0, tzinfo=timezone.utc)

    def test_falls_back_to_24h_when_no_prior_sync(self):
        from looperpowers_sync import compute_cutoff
        before = datetime.now(timezone.utc) - timedelta(hours=25)
        cutoff = compute_cutoff({}, days_override=None)
        assert cutoff > before

    def test_days_override_ignores_last_sync(self):
        from looperpowers_sync import compute_cutoff
        status = {"last_successful_sync": "2026-03-01T00:00:00Z"}
        cutoff = compute_cutoff(status, days_override=30)
        expected = datetime.now(timezone.utc) - timedelta(days=30)
        # Should be within 5 seconds of expected
        assert abs((cutoff - expected).total_seconds()) < 5


class TestDedupGuard:
    def test_skips_if_run_within_23_hours(self):
        from looperpowers_sync import should_skip_dedup
        recent = (datetime.now(timezone.utc) - timedelta(hours=10)).strftime("%Y-%m-%dT%H:%M:%SZ")
        status = {"last_run": {"started_at": recent, "status": "completed"}}
        assert should_skip_dedup(status) is True

    def test_proceeds_if_last_run_over_23_hours_ago(self):
        from looperpowers_sync import should_skip_dedup
        old = (datetime.now(timezone.utc) - timedelta(hours=25)).strftime("%Y-%m-%dT%H:%M:%SZ")
        status = {"last_run": {"started_at": old, "status": "completed"}}
        assert should_skip_dedup(status) is False

    def test_proceeds_if_no_prior_run(self):
        from looperpowers_sync import should_skip_dedup
        assert should_skip_dedup({}) is False


class TestParseRelevance:
    def test_yes_is_relevant(self):
        from looperpowers_sync import parse_relevance_response
        assert parse_relevance_response("YES\n") is True
        assert parse_relevance_response("yes") is True
        assert parse_relevance_response("  Yes  ") is True

    def test_no_is_not_relevant(self):
        from looperpowers_sync import parse_relevance_response
        assert parse_relevance_response("NO\n") is False
        assert parse_relevance_response("no") is False

    def test_empty_or_error_is_not_relevant(self):
        from looperpowers_sync import parse_relevance_response
        assert parse_relevance_response("") is False
        assert parse_relevance_response("   ") is False
        assert parse_relevance_response("Error: something failed") is False

    def test_multiline_takes_first_word(self):
        from looperpowers_sync import parse_relevance_response
        assert parse_relevance_response("YES\nSome explanation") is True


class TestMergeWriteStatus:
    def test_preserves_last_successful_sync_on_new_run(self):
        from looperpowers_sync import merge_write_status

        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump({
                "last_successful_sync": "2026-03-20T09:00:00Z",
                "last_run": {"status": "completed", "scanned": 10, "indexed": 3, "results": []}
            }, f)
            path = f.name

        try:
            merge_write_status(path, {"status": "running", "started_at": "2026-03-24T10:00:00Z",
                                       "scanned": 0, "indexed": 0, "results": []})
            with open(path) as f:
                result = json.load(f)
            assert result["last_successful_sync"] == "2026-03-20T09:00:00Z"
            assert result["last_run"]["status"] == "running"
        finally:
            os.unlink(path)
