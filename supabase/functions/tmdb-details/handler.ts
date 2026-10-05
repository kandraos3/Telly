// TMDB title details (BE-605) for SCR-08 Show Detail, the MVP-character picker (SCR-11)
// and director auto-tagging (FE-204). Upserts `titles` + `tv_seasons` with the service role.
// Spec: docs/technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md §2; SCR-08.
import {
  CATALOG_CACHE_CONTROL,
  corsHeaders,
  json,
  MediaType,
  parseMediaType,
  TMDB_API_BASE,
  tmdbHeaders,
} from "../_shared/http.ts";
import type { CatalogStore, SeasonRow, TitleRow } from "../_shared/db.ts";

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
}

export interface DetailsDeps {
  fetch: typeof fetch;
  tmdbToken: string | undefined;
  store: CatalogStore | null;
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
  };
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
    },
    seasons: d.seasons.map((s) => ({ ...s, title_id: d.id })),
  };
}

export async function handleDetails(req: Request, deps: DetailsDeps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const url = new URL(req.url);
  const id = Number(url.searchParams.get("id"));
  const mediaType = parseMediaType(url.searchParams.get("media_type"));
  if (!Number.isInteger(id) || id <= 0 || !mediaType) {
    return json({ error: "Required query params: id (positive int), media_type ('movie' | 'tv')" }, 400);
  }
  if (!deps.tmdbToken) return json({ error: "Server configuration error: TMDB token not configured" }, 500);

  try {
    const append = mediaType === "tv" ? "credits,aggregate_credits" : "credits";
    const upstream = await deps.fetch(`${TMDB_API_BASE}/${mediaType}/${id}?append_to_response=${append}`, {
      headers: tmdbHeaders(deps.tmdbToken),
    });
    if (upstream.status === 404) return json({ error: "Title not found" }, 404);
    if (upstream.status === 429) return json({ error: "TMDB rate limit exceeded" }, 429, { "Retry-After": "5" });
    if (!upstream.ok) return json({ error: `TMDB upstream error (${upstream.status})` }, 502);

    const details = normalizeDetails(await upstream.json(), mediaType);
    if (deps.store) {
      const rows = toRows(details);
      await deps.store.upsertTitles([rows.title]);
      await deps.store.upsertSeasons(rows.seasons);
    }
    return json(details, 200, { "Cache-Control": CATALOG_CACHE_CONTROL });
  } catch (err) {
    return json({ error: `Internal edge proxy error: ${String(err)}` }, 500);
  }
}
