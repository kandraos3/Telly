// Supabase Edge Function: Explore caches (#177). Logic lives in handler.ts for testability.
import { supabaseExploreStore } from "../_shared/db.ts";
import { handleTitleRelated } from "./handler.ts";

Deno.serve((req) =>
  handleTitleRelated(req, {
    fetch,
    tmdbToken: Deno.env.get("TMDB_ACCESS_TOKEN") ?? Deno.env.get("TMDB_API_KEY"),
    store: supabaseExploreStore(),
    serviceRoleKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
  })
);
