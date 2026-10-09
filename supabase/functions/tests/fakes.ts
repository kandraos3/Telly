// Test doubles for edge-function handlers.
import type {
  AvailabilityRow,
  CatalogStore,
  CollectionRow,
  EpisodeRow,
  EpisodeStore,
  ExploreSeedRef,
  ExploreStore,
  SeasonRow,
  TitleRow,
  TrackingRefreshStore,
} from "../_shared/db.ts";
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
  collections: CollectionRow[] = [];
  collectionFetched: Record<number, string> = {};
  needingDetails: { id: number; media_type: MediaType }[] = [];
  staleCollectionIds: number[] = [];

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
  collectionFetchedAt(collectionId: number) {
    return Promise.resolve(this.collectionFetched[collectionId] ?? null);
  }
  upsertCollection(row: CollectionRow) {
    this.collections.push(row);
    this.collectionFetched[row.collection_id] = new Date().toISOString();
    return Promise.resolve();
  }
  titlesNeedingDetails(limit: number) {
    return Promise.resolve(this.needingDetails.slice(0, limit));
  }
  staleCollections(_maxAgeDays: number, limit: number) {
    return Promise.resolve(this.staleCollectionIds.slice(0, limit));
  }
}

/** In-memory Explore caches for title-related tests. */
export class MemoryExploreStore implements ExploreStore {
  titles: TitleRow[] = [];
  related = new Map<string, { related_id: number; position: number }[]>();
  relatedFetched: Record<string, string> = {};
  trending: Record<string, number[]> = {};
  trendingFetched: Record<string, string> = {};
  stale: ExploreSeedRef[] = [];

  upsertTitles(rows: TitleRow[]) {
    this.titles.push(...rows);
    return Promise.resolve();
  }
  relatedFetchedAt(seedIds: number[], mediaType: MediaType) {
    const out: Record<number, string> = {};
    for (const id of seedIds) {
      const at = this.relatedFetched[`${mediaType}:${id}`];
      if (at) out[id] = at;
    }
    return Promise.resolve(out);
  }
  storeRelated(seedId: number, mediaType: MediaType, related: { related_id: number; position: number }[]) {
    this.related.set(`${mediaType}:${seedId}`, related);
    this.relatedFetched[`${mediaType}:${seedId}`] = new Date().toISOString();
    return Promise.resolve(related.length);
  }
  trendingFetchedAt(mediaType: MediaType) {
    return Promise.resolve(this.trendingFetched[mediaType] ?? null);
  }
  storeTrending(mediaType: MediaType, titleIds: number[]) {
    this.trending[mediaType] = titleIds;
    this.trendingFetched[mediaType] = new Date().toISOString();
    return Promise.resolve(titleIds.length);
  }
  staleSeeds(_maxAgeDays: number, limit: number) {
    return Promise.resolve(this.stale.slice(0, limit));
  }
}

/** In-memory episode cache for tmdb-season and tracking-refresh tests (#227). */
export class MemoryEpisodeStore implements EpisodeStore {
  rows: EpisodeRow[] = [];

  upsertEpisodes(rows: EpisodeRow[]) {
    this.rows.push(...rows);
    return Promise.resolve();
  }
}

/** The database side of tracking-refresh: scripted show and season selection, counted flips. */
export class MemoryTrackingStore implements TrackingRefreshStore {
  shows: number[] = [];
  seasons: Record<number, number[]> = {};
  flipped = 0;
  flipRuns = 0;
  lastIncludeEnded: boolean | null = null;
  lastLimit = 0;

  showsToRefresh(includeEnded: boolean, limit: number) {
    this.lastIncludeEnded = includeEnded;
    this.lastLimit = limit;
    return Promise.resolve(this.shows.slice(0, limit));
  }
  seasonsToRefresh(titleId: number) {
    return Promise.resolve(this.seasons[titleId] ?? []);
  }
  refreshNewEpisodes() {
    this.flipRuns++;
    return Promise.resolve(this.flipped);
  }
}
