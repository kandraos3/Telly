// Daily catalog synchronizer (BE-403 / BE-605). Replaces the previous simulated response.
// Refreshes availability for watchlisted titles whose cache is stale, then recomputes
// `is_leaving_soon` flags. Invoked by a scheduler with the service-role key as Bearer token.
// Spec: docs/technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md §3, features/07 §4.
import { json, isServiceRoleRequest } from "../_shared/http.ts";
import type { CatalogStore } from "../_shared/db.ts";
import { AvailabilityDeps, CACHE_TTL_HOURS, fetchAvailability } from "../streaming-availability/handler.ts";

export interface SyncDeps extends AvailabilityDeps {
  store: CatalogStore;
  serviceRoleKey: string | undefined;
  country?: string;
  batchSize?: number;
}

export async function handleCatalogSync(req: Request, deps: SyncDeps): Promise<Response> {
  if (!isServiceRoleRequest(req, deps.serviceRoleKey)) {
    return json({ error: "Unauthorized" }, 401);
  }

  const country = deps.country ?? "US";
  const stale = await deps.store.staleWatchlistTitles(CACHE_TTL_HOURS, deps.batchSize ?? 50);
  let refreshed = 0;
  const failures: string[] = [];

  for (const t of stale) {
    try {
      const { providers } = await fetchAvailability(t.title_id, t.media_type, country, deps);
      await deps.store.replaceAvailability(
        t.title_id,
        t.media_type,
        country,
        providers.map((p) => ({
          title_id: t.title_id,
          media_type: t.media_type,
          platform_id: p.platform_id,
          country_code: country,
          monetization_type: p.monetization_type,
          deep_link_url: p.web_url,
          available_until: p.available_until,
          is_leaving_soon: p.is_leaving_soon,
        })),
      );
      refreshed++;
    } catch (e) {
      failures.push(`${t.media_type}:${t.title_id}: ${String(e)}`);
    }
  }

  const leavingSoon = await deps.store.refreshLeavingSoonFlags();
  return json({ status: failures.length ? "partial" : "success", checked: stale.length, refreshed, leavingSoon, failures });
}
