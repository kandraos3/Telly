// Daily tracking refresh (#227, epic #168, features/11 §4.8, §6.5). pg_cron calls it at 05:23 UTC
// through `_invoke_edge_function`, with the service-role key as Bearer token.
//
//   1. Series someone tracks as caught up or finished (ended or canceled ones only on Mondays),
//      up to MAX_SHOWS_PER_RUN, least recently refreshed first.
//   2. For each: refresh `titles` + `tv_seasons` through the tmdb-details code path, then fetch
//      the episodes of the seasons that need it (the latest, undated or unaired, partly cached).
//   3. `refresh_tracking_new_episodes()` flips rows whose next episode has now aired.
// A TMDB 429, or running out of the time budget, stops step 2; step 3 still runs, and the next
// day carries on (the least recently refreshed shows come first).
import { isServiceRoleRequest, json } from "../_shared/http.ts";
import type { CatalogStore, EpisodeStore, TrackingRefreshStore } from "../_shared/db.ts";
import { fetchAndStore } from "../tmdb-details/handler.ts";
import { fetchSeason } from "../tmdb-season/handler.ts";

export const MAX_SHOWS_PER_RUN = 500;
/** Stop fetching after this long, inside the platform's wall-clock limit for one invocation. */
export const TIME_BUDGET_MS = 100_000;

export interface RefreshDeps {
  fetch: typeof fetch;
  tmdbToken: string | undefined;
  catalog: CatalogStore;
  episodes: EpisodeStore;
  tracking: TrackingRefreshStore;
  serviceRoleKey: string | undefined;
  now?: () => Date;
}

export async function handleTrackingRefresh(req: Request, deps: RefreshDeps): Promise<Response> {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  if (!isServiceRoleRequest(req, deps.serviceRoleKey)) return json({ error: "Unauthorized" }, 401);
  if (!deps.tmdbToken) return json({ error: "Server configuration error: TMDB token not configured" }, 500);

  const clock = deps.now ?? (() => new Date());
  const started = clock();
  const includeEnded = started.getUTCDay() === 1; // Monday
  const failures: string[] = [];
  let shows = 0;
  let seasons = 0;
  let rateLimited = false;
  let timedOut = false;

  try {
    const titleIds = await deps.tracking.showsToRefresh(includeEnded, MAX_SHOWS_PER_RUN);
    const details = { fetch: deps.fetch, tmdbToken: deps.tmdbToken, store: deps.catalog, now: deps.now };
    const seasonDeps = { fetch: deps.fetch, tmdbToken: deps.tmdbToken, store: deps.episodes };

    for (const id of titleIds) {
      if (rateLimited) break;
      if (clock().getTime() - started.getTime() > TIME_BUDGET_MS) {
        timedOut = true;
        break;
      }
      try {
        const outcome = await fetchAndStore(id, "tv", details);
        if (outcome.status === 429) {
          rateLimited = true;
          break;
        }
        if (outcome.status !== 200) {
          failures.push(`tv:${id} (${outcome.status})`);
          continue;
        }
        shows++;
        for (const season of await deps.tracking.seasonsToRefresh(id)) {
          const result = await fetchSeason(id, season, seasonDeps);
          if (result.status === 429) {
            rateLimited = true;
            break;
          }
          if (result.status === 200) seasons++;
          else failures.push(`tv:${id} s${season} (${result.status})`);
        }
      } catch (err) {
        failures.push(`tv:${id} (${String(err)})`);
      }
    }

    const flipped = await deps.tracking.refreshNewEpisodes();
    return json({ shows, seasons, flipped, rateLimited, timedOut, includeEnded, failures });
  } catch (err) {
    return json({ error: `Tracking refresh failed: ${String(err)}` }, 500);
  }
}
