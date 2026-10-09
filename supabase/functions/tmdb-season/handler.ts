// TMDB season episodes (#227, epic #168, features/11 §6.5): `GET ?id=&season=` fetches one
// season's episodes from TMDB, caches them in `tv_episodes` with the service role, and returns
// them. The app calls it when a tracked title's page opens and a season's episodes are missing or
// older than 7 days (names, stills and air dates for the Next episode card and the seasons list).
// Season 0 (TMDB specials) is refused: tracking ignores it.
import { corsHeaders, isAuthenticatedUserRequest, isServiceRoleRequest, json, TMDB_API_BASE, tmdbHeaders } from "../_shared/http.ts";
import type { EpisodeRow, EpisodeStore } from "../_shared/db.ts";

export interface SeasonDeps {
  fetch: typeof fetch;
  tmdbToken: string | undefined;
  store: EpisodeStore | null;
  serviceRoleKey?: string;
}

export type SeasonOutcome = { status: number; body: unknown };

const validDate = (d: unknown): string | null => (typeof d === "string" && /^\d{4}-\d{2}-\d{2}$/.test(d) ? d : null);

/** TMDB `/tv/{id}/season/{n}` → `tv_episodes` rows. Rows without a positive episode number are dropped. */
export function normalizeEpisodes(raw: Record<string, unknown>, titleId: number, season: number): EpisodeRow[] {
  return ((raw.episodes as Record<string, unknown>[] | undefined) ?? [])
    .filter((e) => Number.isInteger(Number(e.episode_number)) && Number(e.episode_number) >= 1)
    .map((e) => ({
      title_id: titleId,
      season_number: season,
      episode_number: Number(e.episode_number),
      name: ((e.name as string) || "").substring(0, 200) || null,
      overview: (e.overview as string) || null,
      still_path: (e.still_path as string) || null,
      air_date: validDate(e.air_date),
      runtime_minutes: Number(e.runtime) > 0 ? Number(e.runtime) : null,
    }));
}

/** Fetches one season and stores it. Shared with tracking-refresh. */
export async function fetchSeason(titleId: number, season: number, deps: SeasonDeps): Promise<SeasonOutcome> {
  const upstream = await deps.fetch(`${TMDB_API_BASE}/tv/${titleId}/season/${season}`, {
    headers: tmdbHeaders(deps.tmdbToken!),
  });
  if (upstream.status === 404) return { status: 404, body: { error: "Season not found" } };
  if (upstream.status === 429) return { status: 429, body: { error: "TMDB rate limit exceeded" } };
  if (!upstream.ok) return { status: 502, body: { error: `TMDB upstream error (${upstream.status})` } };

  const episodes = normalizeEpisodes(await upstream.json(), titleId, season);
  if (deps.store) await deps.store.upsertEpisodes(episodes);
  return { status: 200, body: { title_id: titleId, season_number: season, episodes } };
}

export async function handleSeason(req: Request, deps: SeasonDeps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "GET") return json({ error: "Method not allowed" }, 405);
  if (!isAuthenticatedUserRequest(req) && !isServiceRoleRequest(req, deps.serviceRoleKey)) {
    return json({ error: "Unauthorized" }, 401);
  }
  if (!deps.tmdbToken) return json({ error: "Server configuration error: TMDB token not configured" }, 500);

  const url = new URL(req.url);
  const id = Number(url.searchParams.get("id"));
  const season = Number(url.searchParams.get("season"));
  if (!Number.isInteger(id) || id <= 0 || !Number.isInteger(season) || season < 1) {
    return json({ error: "Required query params: id (positive int), season (int, 1 or more)" }, 400);
  }

  try {
    const outcome = await fetchSeason(id, season, deps);
    if (outcome.status === 429) return json(outcome.body, 429, { "Retry-After": "5" });
    if (outcome.status !== 200) return json(outcome.body, outcome.status);
    return json(outcome.body, 200, { "Cache-Control": "private, max-age=3600" });
  } catch (err) {
    return json({ error: `Internal edge proxy error: ${String(err)}` }, 500);
  }
}
