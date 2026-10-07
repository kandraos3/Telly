// Supabase Edge Function: TMDB title details (BE-605). Logic lives in handler.ts for testability.
import { supabaseCatalogStore } from "../_shared/db.ts";
import { handleDetails } from "./handler.ts";

Deno.serve((req) =>
  handleDetails(req, {
    fetch,
    tmdbToken: Deno.env.get("TMDB_ACCESS_TOKEN") ?? Deno.env.get("TMDB_API_KEY"),
    store: supabaseCatalogStore(),
    serviceRoleKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
  })
);
