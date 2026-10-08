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

/**
 * Whether [req] comes from a scheduled job (pg_cron → `_invoke_edge_function`) holding the
 * service-role token. Accepts an exact match with the platform's SUPABASE_SERVICE_ROLE_KEY, or
 * any JWT whose `role` claim is `service_role`. The second form is safe only because the Supabase
 * gateway verifies the JWT signature before the function runs: `verify_jwt = true` is pinned for
 * these functions in supabase/config.toml. It's needed because the platform's env value can
 * differ from the dashboard's legacy service_role token while both are valid (#152).
 */
export function isServiceRoleRequest(req: Request, serviceRoleKey: string | undefined): boolean {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return false;
  const token = auth.slice("Bearer ".length).trim();
  if (!token) return false;
  if (serviceRoleKey && token === serviceRoleKey) return true;
  return jwtRole(token) === "service_role";
}

/** The `role` claim of a JWT, without checking its signature (the gateway does that). */
function jwtRole(token: string): string | null {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const payload = JSON.parse(atob(b64 + "=".repeat((4 - (b64.length % 4)) % 4)));
    return typeof payload?.role === "string" ? payload.role : null;
  } catch {
    return null;
  }
}
