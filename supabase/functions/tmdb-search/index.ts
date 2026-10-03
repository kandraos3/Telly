// Supabase Edge Function: TMDB Search Proxy with Edge Caching
// Conforms to `docs/technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md` §1
// and `docs/features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md` §1.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const TMDB_API_BASE = "https://api.themoviedb.org/3";

interface NormalizedSearchResult {
  id: number;
  title: string;
  media_type: "movie" | "tv";
  release_year: string;
  poster_path: string | null;
  backdrop_path: string | null;
  overview: string;
  vote_average: number;
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const query = url.searchParams.get("query")?.trim();
    const page = url.searchParams.get("page") || "1";

    if (!query) {
      return new Response(
        JSON.stringify({ error: "Missing required 'query' parameter" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const tmdbToken = Deno.env.get("TMDB_ACCESS_TOKEN") || Deno.env.get("TMDB_API_KEY");
    if (!tmdbToken) {
      return new Response(
        JSON.stringify({
          error: "Server configuration error: TMDB access token not configured in secrets",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const tmdbUrl = `${TMDB_API_BASE}/search/multi?query=${encodeURIComponent(
      query
    )}&page=${page}&include_adult=false`;

    const upstreamResponse = await fetch(tmdbUrl, {
      headers: {
        Authorization: `Bearer ${tmdbToken}`,
        Accept: "application/json",
      },
    });

    if (upstreamResponse.status === 429) {
      return new Response(
        JSON.stringify({ error: "TMDB rate limit exceeded. Please retry shortly." }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
            "Retry-After": "5",
          },
        }
      );
    }

    if (!upstreamResponse.ok) {
      return new Response(
        JSON.stringify({
          error: `TMDB upstream error (${upstreamResponse.status}): ${upstreamResponse.statusText}`,
        }),
        {
          status: upstreamResponse.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const tmdbData = await upstreamResponse.json();
    const rawResults = (tmdbData.results || []) as Array<Record<string, unknown>>;

    // Normalize results: filter out 'person' type, map movie/tv unified fields
    const normalized: NormalizedSearchResult[] = [];

    for (const item of rawResults) {
      const mediaType = item.media_type as string;
      if (mediaType !== "movie" && mediaType !== "tv") {
        continue;
      }

      const title =
        mediaType === "movie"
          ? (item.title as string) || (item.original_title as string) || "Untitled Movie"
          : (item.name as string) || (item.original_name as string) || "Untitled TV Show";

      const releaseDate =
        mediaType === "movie"
          ? (item.release_date as string) || ""
          : (item.first_air_date as string) || "";

      const releaseYear = releaseDate.length >= 4 ? releaseDate.substring(0, 4) : "";

      normalized.push({
        id: item.id as number,
        title,
        media_type: mediaType as "movie" | "tv",
        release_year: releaseYear,
        poster_path: (item.poster_path as string) || null,
        backdrop_path: (item.backdrop_path as string) || null,
        overview: (item.overview as string) || "",
        vote_average: Number(item.vote_average) || 0.0,
      });
    }

    return new Response(
      JSON.stringify({
        page: tmdbData.page || 1,
        total_pages: tmdbData.total_pages || 1,
        total_results: normalized.length,
        results: normalized,
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
          // Spec: 1-hour to 7-day edge cache for static catalog queries
          "Cache-Control": "public, max-age=86400, s-maxage=604800",
        },
      }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: `Internal edge proxy error: ${String(err)}` }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
