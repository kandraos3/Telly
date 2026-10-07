"""Tests for tool/challenges/publish.py (#143). Run: python tool/challenges/test_publish.py"""
import copy
import datetime as dt
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import publish  # noqa: E402

TEMPLATE = {
    'key': 'genre_month', 'name': 'Genre month', 'description': 'Rank $target $genre films', 'art': 'gold',
    'medal_glyph': 'G', 'params': ['genre'], 'target': 8,
    'rule': {'media_type': 'movie', 'filters': [{'type': 'genre', 'any': ['$genre']}]},
}
CHALLENGE = {
    'slug': 'spooktober-2026', 'name': 'Spooktober', 'description': "Rank 8 horror films, it's October",
    'art': 'horror', 'medal_glyph': '8', 'target': 8, 'featured': True,
    'starts_at': dt.datetime(2026, 10, 1, tzinfo=dt.timezone.utc),
    'ends_at': dt.datetime(2026, 11, 1, tzinfo=dt.timezone.utc),
    'rule': {'media_type': 'movie', 'filters': [{'type': 'genre', 'any': ['Horror']}]},
}


def content(**overrides):
    base = {
        'templates': {'genre_month.yaml': copy.deepcopy(TEMPLATE)},
        'challenges': {'spooktober-2026.yaml': copy.deepcopy(CHALLENGE)},
        'calendar': {'2026-11': [{'slug': 'comedy-november-2026', 'template': 'genre_month', 'name': 'Comedy November',
                                  'params': {'genre': 'Comedy'}, 'featured': True}]},
    }
    base.update(overrides)
    return base


class ValidateTest(unittest.TestCase):
    def test_repo_content_is_valid(self):
        self.assertEqual(publish.validate(publish.load()), [])

    def test_valid_sample(self):
        self.assertEqual(publish.validate(content()), [])

    def assertProblem(self, c, fragment):
        errors = publish.validate(c)
        self.assertTrue(any(fragment in e for e in errors), f'{fragment!r} not in {errors}')

    def test_unknown_filter_type(self):
        c = content()
        c['challenges']['spooktober-2026.yaml']['rule']['filters'][0]['type'] = 'mood'
        self.assertProblem(c, 'type must be one of')

    def test_decade_values(self):
        c = content()
        c['challenges']['spooktober-2026.yaml']['rule'] = {
            'media_type': 'movie', 'filters': [{'type': 'decade', 'any': [1985]}]}
        self.assertProblem(c, 'decades are years ending in 0')

    def test_placeholders_only_in_templates(self):
        c = content()
        c['challenges']['spooktober-2026.yaml']['rule']['filters'][0]['any'] = ['$genre']
        self.assertProblem(c, 'placeholder $genre outside a template')

    def test_template_params_match_placeholders(self):
        c = content()
        c['templates']['genre_month.yaml']['params'] = ['genre', 'mood']
        self.assertProblem(c, 'must match the rule placeholders')

    def test_calendar_params_must_match_template(self):
        c = content()
        c['calendar']['2026-11'][0]['params'] = {}
        self.assertProblem(c, "params must be exactly ['genre']")

    def test_unknown_template(self):
        c = content()
        c['calendar']['2026-11'][0]['template'] = 'nope'
        self.assertProblem(c, "unknown template 'nope'")

    def test_slug_format_and_uniqueness(self):
        c = content()
        c['challenges']['spooktober-2026.yaml']['slug'] = 'Spooktober 2026'
        self.assertProblem(c, 'slug must be lowercase words')
        c = content()
        c['calendar']['2026-11'][0]['slug'] = 'spooktober-2026'
        self.assertProblem(c, 'is also used by')

    def test_dates_need_zones_and_order(self):
        c = content()
        c['challenges']['spooktober-2026.yaml']['starts_at'] = '2026-10-01T00:00:00'
        self.assertProblem(c, 'needs a time zone')
        c = content()
        c['challenges']['spooktober-2026.yaml']['ends_at'] = dt.datetime(2026, 9, 1, tzinfo=dt.timezone.utc)
        self.assertProblem(c, 'ends_at must be after starts_at')

    def test_one_featured_at_a_time(self):
        c = content()
        c['calendar']['2026-10'] = [{'slug': 'clash-2026-10', 'template': 'genre_month', 'name': 'Clash',
                                     'params': {'genre': 'Comedy'}, 'featured': True}]
        self.assertProblem(c, 'one featured challenge at a time')
        c = content()
        c['calendar']['2026-11'].append({'slug': 'second-2026-11', 'template': 'genre_month', 'name': 'Second',
                                         'params': {'genre': 'Drama'}, 'featured': True})
        self.assertProblem(c, 'at most one featured challenge a month')

    def test_glyph_and_target_limits(self):
        c = content()
        c['challenges']['spooktober-2026.yaml']['medal_glyph'] = 'TOOLONG'
        c['challenges']['spooktober-2026.yaml']['target'] = 0
        errors = publish.validate(c)
        self.assertTrue(any('medal_glyph' in e for e in errors))
        self.assertTrue(any('target must be' in e for e in errors))


class SqlTest(unittest.TestCase):
    def test_sql_upserts_everything_then_schedules_two_months(self):
        sql = publish.to_sql(content(), today=dt.date(2026, 12, 15))
        self.assertIn('admin_upsert_challenge_template(', sql)
        self.assertIn('admin_upsert_challenge(', sql)
        self.assertIn('"month":"2026-11-01"', sql)
        self.assertIn("schedule_calendar_challenges('2026-12-01')", sql)
        self.assertIn("schedule_calendar_challenges('2027-01-01')", sql)
        self.assertTrue(sql.strip().startswith('-- Generated') and sql.strip().endswith('COMMIT;'))

    def test_quotes_are_escaped(self):
        sql = publish.to_sql(content(), today=dt.date(2026, 10, 1))
        self.assertIn("it''s October", sql)

    def test_cli_dry_run(self):
        self.assertEqual(publish.main(['--dry-run']), 0)


if __name__ == '__main__':
    unittest.main()
