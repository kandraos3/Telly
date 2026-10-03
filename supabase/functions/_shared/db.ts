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
  };
}
