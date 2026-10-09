-- Migration 20261010003500_drop_old_recommendation_rpcs.sql
-- #191 (follow-up to #182, epic #46): drop the RPCs that get_explore_candidates replaced.
-- No app code calls them since #182, and no build that does is installed anywhere.
-- Spec: docs/technical_architecture/02_DATABASE_SCHEMA_AND_STORED_PROCEDURES.md §3.3;
--       docs/features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md §7.6.

DROP FUNCTION IF EXISTS public.get_recommended_titles(public.media_type_enum, INT);
DROP FUNCTION IF EXISTS public.get_trending_titles(public.media_type_enum, INT);
