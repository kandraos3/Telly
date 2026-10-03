// TMDB multi-search proxy (BE-104). Normalizes movie/tv results and caches them into `titles`
// so a searched title can immediately be ranked (user_rankings has an FK to titles).
// Spec: docs/technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md §2, features/07 §1.
import { CATALOG_CACHE_CONTROL, corsHeaders, json, MediaType, TMDB_API_BASE, tmdbHeaders } from "../_shared/http.ts";
import type { CatalogStore, TitleRow } from "../_shared/db.ts";

export interface NormalizedSearchResult {
  id: number;
  title: string;
  media_type: MediaType;
  release_year: string;
  poster_path: string | null;
  backdrop_path: string | null;
  overview: string;
  vote_average: number;
  popularity: number;
  is_anime: boolean;
}

export interface SearchDeps {
  fetch: typeof fetch;
  tmdbToken: string | undefined;
  store: CatalogStore | null;
}

const ANIMATION_GENRE_ID = 16;

export function normalizeSearchResults(raw: Array<Record<string, unknown>>): NormalizedSearchResult[] {
  const out: NormalizedSearchResult[] = [];
  for (const item of raw) {
    const mediaType = item.media_type;
    if (mediaType !== "movie" && mediaType !== "tv") continue;

    const title = mediaType === "movie"
      ? (item.title as string) || (item.original_title as string) || "Untitled Movie"
      : (item.name as string) || (item.original_name as string) || "Untitled TV Show";
    const date = (mediaType === "movie" ? item.release_date : item.first_air_date) as string | undefined;
    const genreIds = (item.genre_ids as number[] | undefined) ?? [];
    const origin = (item.origin_country as string[] | undefined) ?? [];

    out.push({
      id: item.id as number,
      title,
      media_type: mediaType,
      release_year: date && date.length >= 4 ? date.substring(0, 4) : "",
      poster_path: (item.poster_path as string) || null,
      backdrop_path: (item.backdrop_path as string) || null,
      overview: (item.overview as string) || "",
      vote_average: Number(item.vote_average) || 0,
      popularity: Number(item.popularity) || 0,
      is_anime: genreIds.includes(ANIMATION_GENRE_ID) &&
        (origin.includes("JP") || item.original_language === "ja"),
    });
  }
  return out;
}

export function toTitleRows(results: NormalizedSearchResult[], raw: Array<Record<string, unknown>>): TitleRow[] {
  const dates = new Map<string, string | null>();
  for (const item of raw) {
    const d = (item.media_type === "movie" ? item.release_date : item.first_air_date) as string | undefined;
    dates.set(`${item.media_type}:${item.id}`, d && /^\d{4}-\d{2}-\d{2}$/.test(d) ? d : null);
  }
  return results.map((r) => ({
    id: r.id,
    media_type: r.media_type,
    title: r.title.substring(0, 255),
    release_date: dates.get(`${r.media_type}:${r.id}`) ?? null,
    poster_path: r.poster_path,
    backdrop_path: r.backdrop_path,
    overview: r.overview,
    is_anime: r.is_anime,
    popularity: r.popularity,
  }));
}

export async function handleSearch(req: Request, deps: SearchDeps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const url = new URL(req.url);
  const query = url.searchParams.get("query")?.trim();
  const page = url.searchParams.get("page") || "1";
  if (!query) return json({ error: "Missing required 'query' parameter" }, 400);
  if (!deps.tmdbToken) return json({ error: "Server configuration error: TMDB token not configured" }, 500);

  try {
    const upstream = await deps.fetch(
      `${TMDB_API_BASE}/search/multi?query=${encodeURIComponent(query)}&page=${encodeURIComponent(page)}&include_adult=false`,
      { headers: tmdbHeaders(deps.tmdbToken) },
    );
    if (upstream.status === 429) {
      return json({ error: "TMDB rate limit exceeded. Please retry shortly." }, 429, { "Retry-After": "5" });
    }
    if (!upstream.ok) return json({ error: `TMDB upstream error (${upstream.status})` }, 502);

    const data = await upstream.json();
    const raw = (data.results ?? []) as Array<Record<string, unknown>>;
    const results = normalizeSearchResults(raw);

    // Best effort: a failed cache write must not fail the search.
    if (deps.store) {
      await deps.store.upsertTitles(toTitleRows(results, raw)).catch((e) => console.error("title cache", e));
    }

    return json(
      { page: data.page ?? 1, total_pages: data.total_pages ?? 1, total_results: results.length, results },
      200,
      { "Cache-Control": CATALOG_CACHE_CONTROL },
    );
  } catch (err) {
    return json({ error: `Internal edge proxy error: ${String(err)}` }, 500);
  }
}
