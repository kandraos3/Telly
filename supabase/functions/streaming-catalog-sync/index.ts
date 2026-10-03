// Supabase Edge Function / daily job: streaming catalog synchronizer (BE-403 / BE-605).
import { supabaseCatalogStore } from "../_shared/db.ts";
import { handleCatalogSync } from "./handler.ts";

Deno.serve((req) =>
  handleCatalogSync(req, {
    fetch,
    tmdbToken: Deno.env.get("TMDB_ACCESS_TOKEN") ?? Deno.env.get("TMDB_API_KEY"),
    watchmodeKey: Deno.env.get("WATCHMODE_API_KEY"),
    serviceRoleKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
    store: supabaseCatalogStore(),
  })
);
