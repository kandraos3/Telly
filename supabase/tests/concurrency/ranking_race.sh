#!/usr/bin/env bash
# BE-603: concurrent insert_user_ranking_atomic calls on one canon must leave a contiguous 1..N permutation.
# Usage: PSQL="psql postgresql://postgres:postgres@127.0.0.1:64322/postgres" supabase/tests/concurrency/ranking_race.sh
# Locally (no psql on host): PSQL="docker exec -i supabase_db_telly-backend-prod psql -U postgres -d postgres"
set -euo pipefail

PSQL="${PSQL:-psql ${DB_URL:-postgresql://postgres:postgres@127.0.0.1:64322/postgres}}"
USER_ID="99999999-0000-0000-0000-000000000099"
TITLES=(157336 496243 129 238 680 693134 155 569094 872585 278 550 13)

run() { $PSQL -v ON_ERROR_STOP=1 -q -t -A "$@"; }

cleanup() { echo "DELETE FROM auth.users WHERE id = '$USER_ID';" | run >/dev/null; }
trap cleanup EXIT

cleanup
echo "INSERT INTO auth.users (id, email) VALUES ('$USER_ID', 'race@test.dev');" | run >/dev/null

pids=()
for title in "${TITLES[@]}"; do
  (
    run <<SQL >/dev/null
BEGIN;
SELECT set_config('request.jwt.claims', '{"sub":"$USER_ID","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT public.insert_user_ranking_atomic($title, 'movie', 1);
COMMIT;
SQL
  ) &
  pids+=($!)
done
for pid in "${pids[@]}"; do wait "$pid"; done

result=$(run <<SQL
SELECT count(*) || ':' || COALESCE(bool_and(rank_position = rn), FALSE)
       || ':' || COALESCE(bool_and(calculated_score = public.canon_score(rank_position, total)), FALSE)
FROM (
  SELECT rank_position, calculated_score,
         row_number() OVER (ORDER BY rank_position) AS rn,
         count(*) OVER ()::INT AS total
  FROM public.user_rankings WHERE user_id = '$USER_ID' AND media_type = 'movie'
) r;
SQL
)

expected="${#TITLES[@]}:true:true"
if [[ "$result" != "$expected" ]]; then
  echo "FAIL: expected $expected (count:contiguous:scores), got $result"
  exit 1
fi
echo "PASS: ${#TITLES[@]} concurrent inserts -> contiguous canon with correct scores ($result)"
