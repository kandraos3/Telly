// TMDB title details (BE-605) for SCR-08 Show Detail, the MVP-character picker (SCR-11)
// and director auto-tagging (FE-204). Upserts `titles` + `tv_seasons` with the service role.
// #140 (features/10 §7–§8): also stores the film's TMDB collection, production companies and
// TV type, keeps `title_collections` fresh (weekly), and has a service-role maintenance mode
// (any POST with the service-role key) that backfills older titles and refreshes stale collections.
// Spec: docs/technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md §2; SCR-08.
import { CATALOG_CACHE_CONTROL, corsHeaders, json, MediaType, parseMediaType, TMDB_API_BASE, tmdbHeaders, isServiceRoleRequest } from "../_shared/http.ts";
import type { CatalogStore, CollectionRow, SeasonRow, TitleRow } from "../_shared/db.ts";

/** The metadata version written by this function; older rows are backfilled. */
export const METADATA_VERSION = 2;
/** `title_collections` rows older than this are refetched (features/10 §7). */
export const COLLECTION_MAX_AGE_DAYS = 7;

export interface CastMember {
  name: string;
  character: string;
  profile_path: string | null;
}

export interface TitleDetails {
  id: number;
  media_type: MediaType;
  title: string;
  original_title: string | null;
  overview: string;
  release_date: string | null;
  last_air_date: string | null;
  status: string | null;
  poster_path: string | null;
  backdrop_path: string | null;
  genres: string[];
  network: string | null;
  runtime_minutes: number | null;
  number_of_seasons: number | null;
  number_of_episodes: number | null;
  director: string | null;
  creators: string[];
  cast: CastMember[];
  popularity: number;
  vote_average: number;
  is_anime: boolean;
  seasons: Omit<SeasonRow, "title_id">[];
  collection: { id: number; name: string } | null;
  production_companies: string[];
  tv_type: string | null;
}

export interface DetailsDeps {
  fetch: typeof fetch;
  tmdbToken: string | undefined;
  store: CatalogStore | null;
  /** Required for the maintenance mode (the scheduler calls with it as Bearer token). */
  serviceRoleKey?: string;
  now?: () => Date;
}

const validDate = (d: unknown): string | null => (typeof d === "string" && /^\d{4}-\d{2}-\d{2}$/.test(d) ? d : null);

export function normalizeDetails(raw: Record<string, unknown>, mediaType: MediaType): TitleDetails {
  const genres = ((raw.genres as { name: string }[] | undefined) ?? []).map((g) => g.name);
  const credits = (raw.credits as { cast?: Record<string, unknown>[]; crew?: Record<string, unknown>[] }) ?? {};
  // Series: aggregate_credits spans every season (credits only lists the latest one), and
  // its characters live under roles[] (BE-DETAIL-01).
  const aggregate = (raw.aggregate_credits as { cast?: Record<string, unknown>[] } | undefined)?.cast;
  const castSource = mediaType === "tv" && aggregate && aggregate.length > 0
    ? [...aggregate].sort((a, b) => Number(a.order ?? 0) - Number(b.order ?? 0))
    : credits.cast ?? [];
  const cast = castSource.slice(0, 10).map((c) => ({
    name: String(c.name ?? ""),
    character: String(
      c.character ?? (c.roles as { character?: string }[] | undefined)?.[0]?.character ?? "",
    ),
    profile_path: (c.profile_path as string) || null,
  }));
  const director = (credits.crew ?? []).find((c) => c.job === "Director")?.name as string | undefined;
  const origin = (raw.origin_country as string[] | undefined) ?? [];
  const isTv = mediaType === "tv";
  const seasons = isTv
    ? ((raw.seasons as Record<string, unknown>[] | undefined) ?? [])
      .filter((s) => Number(s.season_number) > 0) // TMDB season 0 = specials
      .map((s) => ({
        season_number: Number(s.season_number),
        name: (s.name as string) || null,
        episode_count: Number(s.episode_count) || 0,
        air_date: validDate(s.air_date),
        poster_path: (s.poster_path as string) || null,
        overview: (s.overview as string) || null,
      }))
    : [];

  return {
    id: Number(raw.id),
    media_type: mediaType,
    title: String((isTv ? raw.name : raw.title) ?? "Untitled"),
    original_title: ((isTv ? raw.original_name : raw.original_title) as string) || null,
    overview: (raw.overview as string) || "",
    release_date: validDate(isTv ? raw.first_air_date : raw.release_date),
    last_air_date: isTv ? validDate(raw.last_air_date) : null,
    status: (raw.status as string) || null,
    poster_path: (raw.poster_path as string) || null,
    backdrop_path: (raw.backdrop_path as string) || null,
    genres,
    network: isTv
      ? ((raw.networks as { name: string }[] | undefined)?.[0]?.name ?? null)
      : ((raw.production_companies as { name: string }[] | undefined)?.[0]?.name ?? null),
    runtime_minutes: isTv
      ? ((raw.episode_run_time as number[] | undefined)?.[0] ?? null)
      : (Number(raw.runtime) || null),
    number_of_seasons: isTv ? Number(raw.number_of_seasons) || seasons.length || null : null,
    number_of_episodes: isTv ? Number(raw.number_of_episodes) || null : null,
    director: isTv ? null : director ?? null,
    creators: isTv ? ((raw.created_by as { name: string }[] | undefined) ?? []).map((c) => c.name) : [],
    cast,
    popularity: Number(raw.popularity) || 0,
    vote_average: Number(raw.vote_average) || 0,
    is_anime: genres.includes("Animation") && (origin.includes("JP") || raw.original_language === "ja"),
    seasons,
    collection: collectionOf(raw, isTv),
    production_companies: ((raw.production_companies as { name: string }[] | undefined) ?? [])
      .map((c) => String(c.name ?? "").trim())
      .filter((n) => n.length > 0),
    tv_type: isTv ? ((raw.type as string) || null) : null,
  };
}

function collectionOf(raw: Record<string, unknown>, isTv: boolean): { id: number; name: string } | null {
  const c = raw.belongs_to_collection as { id?: number; name?: string } | null | undefined;
  return !isTv && c && Number(c.id) > 0 ? { id: Number(c.id), name: String(c.name ?? "") } : null;
}

export function toRows(d: TitleDetails): { title: TitleRow; seasons: SeasonRow[] } {
  return {
    title: {
      id: d.id,
      media_type: d.media_type,
      title: d.title.substring(0, 255),
      original_title: d.original_title?.substring(0, 255) ?? null,
      release_date: d.release_date,
      last_air_date: d.last_air_date,
      status: d.status,
      poster_path: d.poster_path,
      backdrop_path: d.backdrop_path,
      overview: d.overview,
      genres: d.genres,
      original_network: d.network?.substring(0, 100) ?? null,
      number_of_seasons: d.number_of_seasons,
      number_of_episodes: d.number_of_episodes,
      runtime_minutes: d.media_type === "movie" ? d.runtime_minutes : null,
      director: d.director?.substring(0, 100) ?? null,
      is_anime: d.is_anime,
      popularity: d.popularity,
      collection_id: d.collection?.id ?? null,
      production_companies: d.production_companies.map((n) => n.substring(0, 100)),
      tv_type: d.tv_type?.substring(0, 30) ?? null,
      metadata_version: METADATA_VERSION,
    },
    seasons: d.seasons.map((s) => ({ ...s, title_id: d.id })),
  };
}

/** A collection from TMDB `/collection/{id}`: its parts, and which are released by [today]. */
export function normalizeCollection(raw: Record<string, unknown>, today: string): {
  row: CollectionRow;
  parts: TitleRow[];
} {
  const parts = ((raw.parts as Record<string, unknown>[] | undefined) ?? [])
    .filter((p) => Number(p.id) > 0)
    .map((p) => ({
      id: Number(p.id),
      title: String(p.title ?? "Untitled").substring(0, 255),
      release_date: validDate(p.release_date),
      poster_path: (p.poster_path as string) || null,
      overview: (p.overview as string) || null,
      popularity: Number(p.popularity) || 0,
    }))
    .sort((a, b) => (a.release_date ?? "9999").localeCompare(b.release_date ?? "9999"));
  const id = Number(raw.id);
  return {
    row: {
      collection_id: id,
      name: String(raw.name ?? "Collection").substring(0, 255),
      poster_path: (raw.poster_path as string) || null,
      part_ids: parts.map((p) => p.id),
      released_part_ids: parts.filter((p) => p.release_date !== null && p.release_date <= today).map((p) => p.id),
    },
    // Minimal rows so a part can be queued before anyone opens it ("Still to watch", #141).
    parts: parts.map((p) => ({ ...p, media_type: "movie" as const, collection_id: id })),
  };
}

export type Outcome = { status: number; body: unknown };

const now = (deps: DetailsDeps) => (deps.now ?? (() => new Date()))();

/** Fetches a title's TMDB details and upserts `titles` + `tv_seasons` (also used by tracking-refresh, #227). */
export async function fetchAndStore(id: number, mediaType: MediaType, deps: DetailsDeps): Promise<Outcome> {
  const append = mediaType === "tv" ? "credits,aggregate_credits" : "credits";
  const upstream = await deps.fetch(`${TMDB_API_BASE}/${mediaType}/${id}?append_to_response=${append}`, {
    headers: tmdbHeaders(deps.tmdbToken!),
  });
  if (upstream.status === 404) return { status: 404, body: { error: "Title not found" } };
  if (upstream.status === 429) return { status: 429, body: { error: "TMDB rate limit exceeded" } };
  if (!upstream.ok) return { status: 502, body: { error: `TMDB upstream error (${upstream.status})` } };

  const details = normalizeDetails(await upstream.json(), mediaType);
  if (deps.store) {
    const rows = toRows(details);
    await deps.store.upsertTitles([rows.title]);
    await deps.store.upsertSeasons(rows.seasons);
    if (details.collection) {
      // The collection is extra for the details response, so a failure here must not fail it.
      try {
        const fetchedAt = await deps.store.collectionFetchedAt(details.collection.id);
        const ageDays = fetchedAt === null ? Infinity : (now(deps).getTime() - Date.parse(fetchedAt)) / 86_400_000;
        if (ageDays >= COLLECTION_MAX_AGE_DAYS) await refreshCollection(details.collection.id, deps);
      } catch (_) {
        // The next maintenance run refreshes it.
      }
    }
  }
  return { status: 200, body: details };
}

/** Refetches one collection into `title_collections` (and its parts into `titles`). */
export async function refreshCollection(collectionId: number, deps: DetailsDeps): Promise<boolean> {
  if (!deps.store) return false;
  const upstream = await deps.fetch(`${TMDB_API_BASE}/collection/${collectionId}`, {
    headers: tmdbHeaders(deps.tmdbToken!),
  });
  if (!upstream.ok) return false;
  const { row, parts } = normalizeCollection(await upstream.json(), now(deps).toISOString().substring(0, 10));
  await deps.store.upsertTitles(parts);
  await deps.store.upsertCollection(row);
  return true;
}

/** Scheduler entry point: backfill titles stored before [METADATA_VERSION], then refresh stale collections. */
async function handleMaintenance(req: Request, deps: DetailsDeps): Promise<Response> {
  if (!isServiceRoleRequest(req, deps.serviceRoleKey)) {
    return json({ error: "Unauthorized" }, 401);
  }
  if (!deps.store) return json({ error: "Server configuration error: no catalog store" }, 500);
  const body = await req.json().catch(() => ({})) as { limit?: number };
  const limit = Math.min(Math.max(Number(body.limit) || 30, 1), 100);
  const failures: string[] = [];

  let titles = 0;
  for (const t of await deps.store.titlesNeedingDetails(limit)) {
    try {
      const outcome = await fetchAndStore(t.id, t.media_type, deps);
      if (outcome.status === 429) break; // rate limited: carry on next run
      if (outcome.status === 200) titles++;
      else failures.push(`${t.media_type}:${t.id} (${outcome.status})`);
    } catch (err) {
      failures.push(`${t.media_type}:${t.id} (${String(err)})`);
    }
  }

  let collections = 0;
  for (const id of await deps.store.staleCollections(COLLECTION_MAX_AGE_DAYS, limit)) {
    try {
      if (await refreshCollection(id, deps)) collections++;
      else failures.push(`collection:${id}`);
    } catch (err) {
      failures.push(`collection:${id} (${String(err)})`);
    }
  }
  return json({ titles, collections, failures });
}

export async function handleDetails(req: Request, deps: DetailsDeps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (!deps.tmdbToken) return json({ error: "Server configuration error: TMDB token not configured" }, 500);
  if (req.method === "POST") return handleMaintenance(req, deps);

  const url = new URL(req.url);
  const id = Number(url.searchParams.get("id"));
  const mediaType = parseMediaType(url.searchParams.get("media_type"));
  if (!Number.isInteger(id) || id <= 0 || !mediaType) {
    return json({ error: "Required query params: id (positive int), media_type ('movie' | 'tv')" }, 400);
  }

  try {
    const outcome = await fetchAndStore(id, mediaType, deps);
    if (outcome.status === 429) return json(outcome.body, 429, { "Retry-After": "5" });
    if (outcome.status !== 200) return json(outcome.body, outcome.status);
    return json(outcome.body, 200, { "Cache-Control": CATALOG_CACHE_CONTROL });
  } catch (err) {
    return json({ error: `Internal edge proxy error: ${String(err)}` }, 500);
  }
}
