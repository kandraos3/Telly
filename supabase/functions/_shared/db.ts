// Service-role persistence used by edge functions (titles are client read-only; Spec 02 §2.4).
import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";
import type { MediaType } from "./http.ts";

export interface TitleRow {
  id: number;
  media_type: MediaType;
  title: string;
  original_title?: string | null;
  release_date?: string | null;
  last_air_date?: string | null;
  status?: string | null;
  poster_path?: string | null;
  backdrop_path?: string | null;
  overview?: string | null;
  genres?: string[];
  original_network?: string | null;
  number_of_seasons?: number | null;
  number_of_episodes?: number | null;
  runtime_minutes?: number | null;
  director?: string | null;
  is_anime?: boolean;
  popularity?: number | null;
  // #140 (features/10 §7–§8): collection and challenge filters.
  collection_id?: number | null;
  production_companies?: string[];
  tv_type?: string | null;
  /** 2 once stored with the #140 fields; the maintenance run backfills lower versions. */
  metadata_version?: number;
  // #177 (features/07 §7.4): a quality signal for titles nobody on Telly has ranked yet.
  tmdb_vote_average?: number | null;
  tmdb_vote_count?: number | null;
}

/** A seed whose TMDB recommendations are due for a refetch (`stale_explore_seeds`). */
export interface ExploreSeedRef {
  seed_id: number;
  media_type: MediaType;
}

/** The Explore caches (#177, features/07 §7.6): `title_related`, `trending_titles` and the fetch log. */
export interface ExploreStore {
  upsertTitles(rows: TitleRow[]): Promise<void>;
  /** When each of [seedIds] last had its recommendations fetched; absent if never. */
  relatedFetchedAt(seedIds: number[], mediaType: MediaType): Promise<Record<number, string>>;
  /** Replaces a seed's related rows and logs the fetch (`store_title_related`). */
  storeRelated(seedId: number, mediaType: MediaType, related: { related_id: number; position: number }[]): Promise<number>;
  /** When the canon's trending list was last stored; null if never. */
  trendingFetchedAt(mediaType: MediaType): Promise<string | null>;
  /** Replaces the canon's trending list, best first (`store_trending`). */
  storeTrending(mediaType: MediaType, titleIds: number[]): Promise<number>;
  staleSeeds(maxAgeDays: number, limit: number): Promise<ExploreSeedRef[]>;
}

/** TMDB collection cache (`title_collections`, features/10 §7). */
export interface CollectionRow {
  collection_id: number;
  name: string;
  poster_path: string | null;
  part_ids: number[];
  released_part_ids: number[];
  fetched_at?: string;
}

export interface SeasonRow {
  title_id: number;
  season_number: number;
  name: string | null;
  episode_count: number;
  air_date: string | null;
  poster_path: string | null;
  overview: string | null;
}

export interface AvailabilityRow {
  title_id: number;
  media_type: MediaType;
  platform_id: string;
  country_code: string;
  monetization_type: string;
  deep_link_url: string | null;
  available_until: string | null;
  is_leaving_soon: boolean;
  updated_at?: string;
}

export interface CatalogStore {
  upsertTitles(rows: TitleRow[]): Promise<void>;
  upsertSeasons(rows: SeasonRow[]): Promise<void>;
  getAvailability(titleId: number, mediaType: MediaType, country: string): Promise<AvailabilityRow[]>;
  replaceAvailability(titleId: number, mediaType: MediaType, country: string, rows: AvailabilityRow[]): Promise<void>;
  staleWatchlistTitles(olderThanHours: number, limit: number): Promise<{ title_id: number; media_type: MediaType }[]>;
  refreshLeavingSoonFlags(): Promise<number>;
  /** When `title_collections` last refreshed this collection; null if never. */
  collectionFetchedAt(collectionId: number): Promise<string | null>;
  upsertCollection(row: CollectionRow): Promise<void>;
  /** Titles stored before the current metadata version, most popular first. */
  titlesNeedingDetails(limit: number): Promise<{ id: number; media_type: MediaType }[]>;
  /** Collections not refreshed for [maxAgeDays]. */
  staleCollections(maxAgeDays: number, limit: number): Promise<number[]>;
}

export function serviceClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not configured");
  return createClient(url, key, { auth: { persistSession: false } });
}

export function supabaseCatalogStore(client: SupabaseClient = serviceClient()): CatalogStore {
  const check = (error: { message: string } | null) => {
    if (error) throw new Error(error.message);
  };
  return {
    async upsertTitles(rows) {
      if (rows.length === 0) return;
      const { error } = await client.from("titles").upsert(rows, { onConflict: "id,media_type" });
      check(error);
    },
    async upsertSeasons(rows) {
      if (rows.length === 0) return;
      const { error } = await client
        .from("tv_seasons")
        .upsert(rows.map((r) => ({ ...r, media_type: "tv" })), { onConflict: "title_id,season_number" });
      check(error);
    },
    async getAvailability(titleId, mediaType, country) {
      const { data, error } = await client
        .from("title_availability")
        .select("*")
        .eq("title_id", titleId)
        .eq("media_type", mediaType)
        .eq("country_code", country);
      check(error);
      return (data ?? []) as AvailabilityRow[];
    },
    async replaceAvailability(titleId, mediaType, country, rows) {
      const del = await client
        .from("title_availability")
        .delete()
        .eq("title_id", titleId)
        .eq("media_type", mediaType)
        .eq("country_code", country);
      check(del.error);
      if (rows.length > 0) {
        const { error } = await client.from("title_availability").insert(rows);
        check(error);
      }
    },
    async staleWatchlistTitles(olderThanHours, limit) {
      const { data, error } = await client.rpc("stale_watchlist_titles", {
        p_older_than_hours: olderThanHours,
        p_limit: limit,
      });
      check(error);
      return (data ?? []) as { title_id: number; media_type: MediaType }[];
    },
    async refreshLeavingSoonFlags() {
      const { data, error } = await client.rpc("refresh_leaving_soon_flags");
      check(error);
      return Number(data ?? 0);
    },
    async collectionFetchedAt(collectionId) {
      const { data, error } = await client
        .from("title_collections")
        .select("fetched_at")
        .eq("collection_id", collectionId)
        .maybeSingle();
      check(error);
      return (data?.fetched_at as string | undefined) ?? null;
    },
    async upsertCollection(row) {
      const { error } = await client
        .from("title_collections")
        .upsert({ ...row, fetched_at: row.fetched_at ?? new Date().toISOString() }, { onConflict: "collection_id" });
      check(error);
    },
    async titlesNeedingDetails(limit) {
      const { data, error } = await client.rpc("titles_needing_details", { p_limit: limit });
      check(error);
      return (data ?? []) as { id: number; media_type: MediaType }[];
    },
    async staleCollections(maxAgeDays, limit) {
      const { data, error } = await client.rpc("stale_title_collections", { p_max_age_days: maxAgeDays, p_limit: limit });
      check(error);
      return ((data ?? []) as { collection_id: number }[]).map((r) => r.collection_id);
    },
  };
}

export function supabaseExploreStore(client: SupabaseClient = serviceClient()): ExploreStore {
  const check = (error: { message: string } | null) => {
    if (error) throw new Error(error.message);
  };
  return {
    async upsertTitles(rows) {
      if (rows.length === 0) return;
      const { error } = await client.from("titles").upsert(rows, { onConflict: "id,media_type" });
      check(error);
    },
    async relatedFetchedAt(seedIds, mediaType) {
      if (seedIds.length === 0) return {};
      const { data, error } = await client
        .from("title_related_fetches")
        .select("seed_id, fetched_at")
        .eq("seed_media_type", mediaType)
        .in("seed_id", seedIds);
      check(error);
      return Object.fromEntries(((data ?? []) as { seed_id: number; fetched_at: string }[]).map((r) => [r.seed_id, r.fetched_at]));
    },
    async storeRelated(seedId, mediaType, related) {
      const { data, error } = await client.rpc("store_title_related", {
        p_seed_id: seedId,
        p_media_type: mediaType,
        p_related: related,
      });
      check(error);
      return Number(data ?? 0);
    },
    async trendingFetchedAt(mediaType) {
      const { data, error } = await client
        .from("trending_titles")
        .select("fetched_at")
        .eq("media_type", mediaType)
        .order("fetched_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      check(error);
      return (data?.fetched_at as string | undefined) ?? null;
    },
    async storeTrending(mediaType, titleIds) {
      const { data, error } = await client.rpc("store_trending", { p_media_type: mediaType, p_title_ids: titleIds });
      check(error);
      return Number(data ?? 0);
    },
    async staleSeeds(maxAgeDays, limit) {
      const { data, error } = await client.rpc("stale_explore_seeds", { p_max_age_days: maxAgeDays, p_limit: limit });
      check(error);
      return (data ?? []) as ExploreSeedRef[];
    },
  };
}
