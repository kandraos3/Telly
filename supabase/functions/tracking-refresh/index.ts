// Supabase Edge Function: daily tracking refresh (#227). Logic lives in handler.ts.
import { serviceClient, supabaseCatalogStore, supabaseEpisodeStore, supabaseTrackingRefreshStore } from "../_shared/db.ts";
import { handleTrackingRefresh } from "./handler.ts";

Deno.serve((req) => {
  const client = serviceClient();
  return handleTrackingRefresh(req, {
    fetch,
    tmdbToken: Deno.env.get("TMDB_ACCESS_TOKEN") ?? Deno.env.get("TMDB_API_KEY"),
    catalog: supabaseCatalogStore(client),
    episodes: supabaseEpisodeStore(client),
    tracking: supabaseTrackingRefreshStore(client),
    serviceRoleKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
  });
});
