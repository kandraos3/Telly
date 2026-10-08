"""Tests for the pure parts of tool/tracker/tracker.py (#158). Run: python tool/tracker/test_tracker.py"""

import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import tracker  # noqa: E402


class TitleTest(unittest.TestCase):
    def test_accepts_conventional_titles(self):
        for title in [
            "feat(explore): add \"Because you ranked X\" carousel rows",
            "fix(theme): raise lime contrast on light-mode canon rows",
            "chore(process): branches, pull requests and a protected main",
            "docs: capture 2026-10-07 voice note",
            "ci(deps): bump the actions group with 2 updates",
            "feat(ranking)!: drop legacy Elo scores",
            'Revert "feat(explore): add carousel rows"',
        ]:
            self.assertIsNone(tracker.title_problem(title), title)

    def test_rejects_titles_that_break_the_convention(self):
        for title in [
            "Add carousel rows",
            "feature(explore): add rows",
            "fix(Theme): capital scope",
            "fix(theme):no space",
            "fix(theme): ",
        ]:
            self.assertIn("<type>(<scope>)", tracker.title_problem(title), title)

    def test_rejects_an_issue_number_suffix(self):
        self.assertIn("drop the trailing", tracker.title_problem("fix(theme): raise contrast (#47)"))

    def test_rejects_overlong_titles(self):
        self.assertIn("under", tracker.title_problem("fix: " + "x" * 120))


class PrBodyTest(unittest.TestCase):
    def test_closes_ordinary_issues_and_refs_the_epic(self):
        body = tracker.pr_body(52, True, [44], "Adds the rows.", deploy=False)
        self.assertTrue(body.startswith("Fixes #52\nRefs #44\n"))
        self.assertIn("Adds the rows.", body)
        self.assertIn("- [ ] Needs `supabase-deploy`", body)

    def test_stage_issues_are_referenced_not_closed(self):
        body = tracker.pr_body(55, False, [], "", deploy=True)
        self.assertTrue(body.startswith("Refs #55\n"))
        self.assertNotIn("Fixes", body)
        self.assertIn("- [x] Needs `supabase-deploy`", body)


class ScaffoldTest(unittest.TestCase):
    def test_owner_ideas_scaffold_straight_away(self):
        self.assertTrue(tracker.should_scaffold(None, tracker.OWNER))
        self.assertTrue(tracker.should_scaffold("Inbox", tracker.OWNER))

    def test_outside_ideas_wait_for_triage(self):
        self.assertFalse(tracker.should_scaffold(None, "someone-else"))
        self.assertFalse(tracker.should_scaffold("Inbox", "someone-else"))
        self.assertTrue(tracker.should_scaffold("Backlog", "someone-else"))


class CheckRollupTest(unittest.TestCase):
    def test_summarises_check_runs_and_statuses(self):
        self.assertEqual(tracker.check_rollup([{"conclusion": "SUCCESS"}, {"conclusion": "SKIPPED"}]), "CI green")
        self.assertEqual(tracker.check_rollup([{"conclusion": "SUCCESS"}, {"conclusion": "FAILURE"}]), "CI failing")
        self.assertEqual(tracker.check_rollup([{"conclusion": "", "status": "IN_PROGRESS"}]), "CI running")
        self.assertEqual(tracker.check_rollup([{"state": "PENDING"}]), "CI running")
        self.assertEqual(tracker.check_rollup([]), "CI running")


if __name__ == "__main__":
    unittest.main()
