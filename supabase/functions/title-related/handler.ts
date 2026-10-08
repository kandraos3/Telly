// Explore caches (#177, epic #46): TMDB recommendations per seed title and TMDB weekly trending,
// stored in title_related / trending_titles for get_explore_candidates.
// Spec: docs/features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md §7.6.
//
//   * A signed-in user POSTs {seed_ids (≤ 5), media_type}: fetches any of those seeds that were
//     never fetched or are over RELATED_MAX_AGE_DAYS old (the app sends profile.missing_related).
//   * The scheduler POSTs with the service-role key (pg_cron 'explore-refresh'): refreshes each
//     canon's trending list when older than TRENDING_MAX_AGE_HOURS, then up to SEEDS_PER_RUN
//     stale seeds from all users' top 5.
//
// Every listed title is upserted into `titles` first (the cache tables reference it), with genre
// names from _shared/genres.ts. New rows have metadata_version 0, so tmdb-details' maintenance
// later fills in director, network and collection.
import { corsHeaders, isAuthenticatedUserRequest, isServiceRoleRequest, json, MediaType, parseMediaType, TMDB_API_BASE, tmdbHeaders } from "../_shared/http.ts";
import type { ExploreStore, TitleRow } from "../_shared/db.ts";
import { genreNames } from "../_shared/genres.ts";

export const RELATED_MAX_AGE_DAYS = 14;
export const TRENDING_MAX_AGE_HOURS = 6;
export const SEEDS_PER_RUN = 40;
export const MAX_USER_SEEDS = 5;
/** TMDB returns 20 results per page; only page 1 is kept. */
export const LIST_SIZE = 20;

const ANIMATION_GENRE_ID = 16;

export interface RelatedDeps {
  fetch: typeof fetch;
  tmdbToken: string | undefined;
  store: ExploreStore | null;
  serviceRoleKey?: string;
  now?: () => Date;
}

const now = (deps: RelatedDeps) => (deps.now ? deps.now() : new Date());
const validDate = (d: unknown): string | null => (typeof d === "string" && /^\d{4}-\d{2}-\d{2}$/.test(d) ? d : null);

/** A TMDB list result (recommendations, trending) as a minimal `titles` row of [mediaType]. */
export function listItemToTitleRow(item: Record<string, unknown>, mediaType: MediaType): TitleRow | null {
  const id = Number(item.id);
  if (!Number.isInteger(id) || id <= 0) return null;
  const title = mediaType === "movie"
    ? (item.title as string) || (item.original_title as string) || "Untitled Movie"
    : (item.name as string) || (item.original_name as string) || "Untitled TV Show";
  const genreIds = ((item.genre_ids as number[] | undefined) ?? []).map(Number);
  const origin = (item.origin_country as string[] | undefined) ?? [];
  const votes = Number(item.vote_count);
  const average = Number(item.vote_average);
  return {
    id,
    media_type: mediaType,
    title: title.substring(0, 255),
    release_date: validDate(mediaType === "movie" ? item.release_date : item.first_air_date),
    poster_path: (item.poster_path as string) || null,
    backdrop_path: (item.backdrop_path as string) || null,
    genres: genreNames(genreIds, mediaType),
    popularity: Number.isFinite(Number(item.popularity)) ? Number(item.popularity) : null,
    tmdb_vote_average: Number.isFinite(average) ? Math.round(average * 10) / 10 : null,
    tmdb_vote_count: Number.isInteger(votes) ? votes : null,
    is_anime: genreIds.includes(ANIMATION_GENRE_ID) && (origin.includes("JP") || item.original_language === "ja"),
  };
}

type ListOutcome = { status: number; rows: TitleRow[] };

/** Fetches a TMDB list page and maps it to title rows, keeping TMDB's order. */
async function fetchList(path: string, mediaType: MediaType, deps: RelatedDeps): Promise<ListOutcome> {
  const upstream = await deps.fetch(`${TMDB_API_BASE}${path}`, { headers: tmdbHeaders(deps.tmdbToken!) });
  if (!upstream.ok) return { status: upstream.status, rows: [] };
  const data = await upstream.json() as { results?: Record<string, unknown>[] };
  const rows: TitleRow[] = [];
  const seen = new Set<number>();
  for (const item of (data.results ?? []).slice(0, LIST_SIZE)) {
    // Trending can mix in people; recommendations stay within the seed's media type.
    if (item.media_type !== undefined && item.media_type !== mediaType) continue;
    const row = listItemToTitleRow(item, mediaType);
    if (row && !seen.has(row.id)) {
      seen.add(row.id);
      rows.push(row);
    }
  }
  return { status: 200, rows };
}

/** Fetches one seed's recommendations into `title_related`. Returns the TMDB status (200 on success). */
export async function refreshSeed(seedId: number, mediaType: MediaType, deps: RelatedDeps): Promise<number> {
  const { status, rows } = await fetchList(`/${mediaType}/${seedId}/recommendations?page=1`, mediaType, deps);
  if (status === 404) {
    // Unknown to TMDB: log an empty fetch so it isn't retried until it goes stale.
    await deps.store!.storeRelated(seedId, mediaType, []);
    return 200;
  }
  if (status !== 200) return status;
  const related = rows.filter((r) => r.id !== seedId);
  await deps.store!.upsertTitles(related);
  await deps.store!.storeRelated(seedId, mediaType, related.map((r, i) => ({ related_id: r.id, position: i + 1 })));
  return 200;
}

export async function refreshTrending(mediaType: MediaType, deps: RelatedDeps): Promise<number> {
  const { status, rows } = await fetchList(`/trending/${mediaType}/week`, mediaType, deps);
  if (status !== 200) return status;
  await deps.store!.upsertTitles(rows);
  await deps.store!.storeTrending(mediaType, rows.map((r) => r.id));
  return 200;
}

const ageHours = (iso: string | null | undefined, at: Date) =>
  iso ? (at.getTime() - Date.parse(iso)) / 3_600_000 : Infinity;

async function handleScheduled(deps: RelatedDeps): Promise<Response> {
  const failures: string[] = [];
  let trending = 0;
  let seeds = 0;
  let rateLimited = false;

  for (const mediaType of ["movie", "tv"] as const) {
    if (ageHours(await deps.store!.trendingFetchedAt(mediaType), now(deps)) < TRENDING_MAX_AGE_HOURS) continue;
    const status = await refreshTrending(mediaType, deps).catch(() => 500);
    if (status === 200) trending++;
    else if (status === 429) rateLimited = true;
    else failures.push(`trending:${mediaType} (${status})`);
    if (rateLimited) break;
  }

  if (!rateLimited) {
    for (const s of await deps.store!.staleSeeds(RELATED_MAX_AGE_DAYS, SEEDS_PER_RUN)) {
      const status = await refreshSeed(s.seed_id, s.media_type, deps).catch(() => 500);
      if (status === 200) seeds++;
      else if (status === 429) {
        rateLimited = true; // carry on next run
        break;
      } else failures.push(`${s.media_type}:${s.seed_id} (${status})`);
    }
  }
  return json({ trending, seeds, rate_limited: rateLimited, failures });
}

async function handleUser(req: Request, deps: RelatedDeps): Promise<Response> {
  const body = await req.json().catch(() => null) as { seed_ids?: unknown; media_type?: unknown } | null;
  const mediaType = parseMediaType(typeof body?.media_type === "string" ? body.media_type : null);
  const ids = Array.isArray(body?.seed_ids) ? body.seed_ids : null;
  if (!mediaType || !ids || ids.length === 0 || ids.length > MAX_USER_SEEDS ||
      !ids.every((id) => Number.isInteger(id) && (id as number) > 0)) {
    return json({ error: `Body must be {seed_ids: 1–${MAX_USER_SEEDS} positive ints, media_type: 'movie' | 'tv'}` }, 400);
  }
  const seedIds = [...new Set(ids as number[])];
  const fetchedAt = await deps.store!.relatedFetchedAt(seedIds, mediaType);
  const refreshed: number[] = [];
  const fresh: number[] = [];
  const failures: string[] = [];
  for (const id of seedIds) {
    if (ageHours(fetchedAt[id], now(deps)) < RELATED_MAX_AGE_DAYS * 24) {
      fresh.push(id);
      continue;
    }
    const status = await refreshSeed(id, mediaType, deps).catch(() => 500);
    if (status === 200) refreshed.push(id);
    else if (status === 429) return json({ error: "TMDB rate limit exceeded", refreshed }, 429, { "Retry-After": "5" });
    else failures.push(`${mediaType}:${id} (${status})`);
  }
  return json({ refreshed, fresh, failures });
}

export async function handleTitleRelated(req: Request, deps: RelatedDeps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);
  if (!deps.tmdbToken) return json({ error: "Server configuration error: TMDB token not configured" }, 500);
  if (!deps.store) return json({ error: "Server configuration error: no store" }, 500);
  try {
    if (isServiceRoleRequest(req, deps.serviceRoleKey)) return await handleScheduled(deps);
    if (isAuthenticatedUserRequest(req)) return await handleUser(req, deps);
    return json({ error: "Unauthorized" }, 401);
  } catch (err) {
    return json({ error: `Internal edge proxy error: ${String(err)}` }, 500);
  }
}
