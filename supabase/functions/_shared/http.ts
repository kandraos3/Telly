// Shared HTTP helpers for Telly edge functions.

export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

export function json(body: unknown, status = 200, extraHeaders: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", ...extraHeaders },
  });
}

export type MediaType = "movie" | "tv";

export function parseMediaType(value: string | null): MediaType | null {
  return value === "movie" || value === "tv" ? value : null;
}

/** Edge cache policy for static catalog lookups (TA-03 §2, BE-104). */
export const CATALOG_CACHE_CONTROL = "public, max-age=86400, s-maxage=604800";

export const TMDB_API_BASE = "https://api.themoviedb.org/3";

export function tmdbHeaders(token: string): HeadersInit {
  return { Authorization: `Bearer ${token}`, Accept: "application/json" };
}
