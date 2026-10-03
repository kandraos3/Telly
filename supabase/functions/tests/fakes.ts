// Test doubles for edge-function handlers.
import type { AvailabilityRow, CatalogStore, SeasonRow, TitleRow } from "../_shared/db.ts";
import type { MediaType } from "../_shared/http.ts";

export interface RecordedCall {
  url: string;
  init?: RequestInit;
}

/** Fake fetch: routes by URL substring; records calls. */
export function fakeFetch(routes: Record<string, () => Response>, calls: RecordedCall[] = []): typeof fetch {
  return ((input: string | URL | Request, init?: RequestInit) => {
    const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
    calls.push({ url, init });
    for (const [needle, respond] of Object.entries(routes)) {
      if (url.includes(needle)) return Promise.resolve(respond());
    }
    return Promise.resolve(new Response("not found", { status: 404 }));
  }) as typeof fetch;
}

export const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

export class MemoryStore implements CatalogStore {
  titles: TitleRow[] = [];
  seasons: SeasonRow[] = [];
  availability: AvailabilityRow[] = [];
  stale: { title_id: number; media_type: MediaType }[] = [];
  leavingSoonRuns = 0;

  upsertTitles(rows: TitleRow[]) {
    this.titles.push(...rows);
    return Promise.resolve();
  }
  upsertSeasons(rows: SeasonRow[]) {
    this.seasons.push(...rows);
    return Promise.resolve();
  }
  getAvailability(titleId: number, mediaType: MediaType, country: string) {
    return Promise.resolve(
      this.availability.filter((r) => r.title_id === titleId && r.media_type === mediaType && r.country_code === country),
    );
  }
  replaceAvailability(titleId: number, mediaType: MediaType, country: string, rows: AvailabilityRow[]) {
    this.availability = this.availability
      .filter((r) => !(r.title_id === titleId && r.media_type === mediaType && r.country_code === country))
      .concat(rows.map((r) => ({ ...r, updated_at: new Date().toISOString() })));
    return Promise.resolve();
  }
  staleWatchlistTitles() {
    return Promise.resolve(this.stale);
  }
  refreshLeavingSoonFlags() {
    this.leavingSoonRuns++;
    return Promise.resolve(this.availability.filter((r) => r.is_leaving_soon).length);
  }
}
