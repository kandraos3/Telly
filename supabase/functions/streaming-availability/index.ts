// Supabase Edge Function: streaming availability (BE-402 / BE-605). Logic lives in handler.ts for testability.
import { supabaseCatalogStore } from "../_shared/db.ts";
import { handleAvailability } from "./handler.ts";

Deno.serve((req) =>
  handleAvailability(req, {
    fetch,
    tmdbToken: Deno.env.get("TMDB_ACCESS_TOKEN") ?? Deno.env.get("TMDB_API_KEY"),
    watchmodeKey: Deno.env.get("WATCHMODE_API_KEY"),
    store: supabaseCatalogStore(),
  })
);
