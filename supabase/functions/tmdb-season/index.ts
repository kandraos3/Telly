// Supabase Edge Function: TMDB season episodes (#227). Logic lives in handler.ts for testability.
import { supabaseEpisodeStore } from "../_shared/db.ts";
import { handleSeason } from "./handler.ts";

Deno.serve((req) =>
  handleSeason(req, {
    fetch,
    tmdbToken: Deno.env.get("TMDB_ACCESS_TOKEN") ?? Deno.env.get("TMDB_API_KEY"),
    store: supabaseEpisodeStore(),
    serviceRoleKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
  })
);
