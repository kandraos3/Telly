// Streaming availability (BE-402 / BE-605). Replaces the previous simulated provider list.
// Source order: cached `title_availability` rows (< 24h) → Watchmode (when WATCHMODE_API_KEY is set;
// provides native app links) → TMDB watch providers (JustWatch data, covered by the TMDB token).
// Spec: docs/technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md §3, features/07 §3.
import { corsHeaders, json, MediaType, parseMediaType, TMDB_API_BASE, tmdbHeaders } from "../_shared/http.ts";
import type { AvailabilityRow, CatalogStore } from "../_shared/db.ts";
import { PlatformId, platformFromName, platformFromTmdbId } from "../_shared/providers.ts";

export type Monetization = "flatrate" | "free" | "ads" | "rent" | "buy";

export interface ProviderAvailability {
  platform_id: PlatformId;
  monetization_type: Monetization;
  web_url: string | null;
  ios_url: string | null;
  android_url: string | null;
  available_until: string | null;
  is_leaving_soon: boolean;
}

export interface AvailabilityDeps {
  fetch: typeof fetch;
  tmdbToken: string | undefined;
  watchmodeKey: string | undefined;
  store: CatalogStore | null;
  now?: () => Date;
}

export const CACHE_TTL_HOURS = 24;
const LEAVING_SOON_DAYS = 7;

function leavingSoon(until: string | null, now: Date): boolean {
  if (!until) return false;
  const ms = new Date(`${until}T00:00:00Z`).getTime() - now.getTime();
  return ms <= LEAVING_SOON_DAYS * 86_400_000;
}

function dedupe(items: ProviderAvailability[]): ProviderAvailability[] {
  const seen = new Map<string, ProviderAvailability>();
  for (const p of items) {
    const key = `${p.platform_id}:${p.monetization_type}`;
    if (!seen.has(key)) seen.set(key, p);
  }
  return [...seen.values()];
}

export function fromWatchmode(sources: Record<string, unknown>[], now: Date): ProviderAvailability[] {
  const typeMap: Record<string, Monetization> = { sub: "flatrate", free: "free", rent: "rent", buy: "buy", tve: "flatrate" };
  const out: ProviderAvailability[] = [];
  for (const s of sources) {
    const platform = platformFromName(String(s.name ?? ""));
    const monetization = typeMap[String(s.type ?? "")];
    if (!platform || !monetization) continue;
    const until = typeof s.endDate === "string" ? s.endDate.substring(0, 10) : null;
    out.push({
      platform_id: platform,
      monetization_type: monetization,
      web_url: (s.web_url as string) || null,
      ios_url: (s.ios_url as string) || null,
      android_url: (s.android_url as string) || null,
      available_until: until,
      is_leaving_soon: leavingSoon(until, now),
    });
  }
  return dedupe(out);
}

export function fromTmdb(countryResult: Record<string, unknown> | undefined): ProviderAvailability[] {
  if (!countryResult) return [];
  const link = (countryResult.link as string) || null;
  const out: ProviderAvailability[] = [];
  for (const monetization of ["flatrate", "free", "ads", "rent", "buy"] as Monetization[]) {
    for (const p of (countryResult[monetization] as Record<string, unknown>[] | undefined) ?? []) {
      const platform = platformFromTmdbId(Number(p.provider_id)) ?? platformFromName(String(p.provider_name ?? ""));
      if (!platform) continue;
      out.push({
        platform_id: platform,
        monetization_type: monetization,
        web_url: link,
        ios_url: null,
        android_url: null,
        available_until: null,
        is_leaving_soon: false,
      });
    }
  }
  return dedupe(out);
}

function fromRows(rows: AvailabilityRow[]): ProviderAvailability[] {
  return rows.map((r) => ({
    platform_id: r.platform_id as PlatformId,
    monetization_type: r.monetization_type as Monetization,
    web_url: r.deep_link_url,
    ios_url: null,
    android_url: null,
    available_until: r.available_until,
    is_leaving_soon: r.is_leaving_soon,
  }));
}

export async function fetchAvailability(
  tmdbId: number,
  mediaType: MediaType,
  country: string,
  deps: AvailabilityDeps,
): Promise<{ source: "watchmode" | "tmdb"; providers: ProviderAvailability[] }> {
  const now = deps.now?.() ?? new Date();
  if (deps.watchmodeKey) {
    const res = await deps.fetch(
      `https://api.watchmode.com/v1/title/${mediaType}-${tmdbId}/sources/?apiKey=${deps.watchmodeKey}&regions=${country}`,
    );
    if (res.ok) return { source: "watchmode", providers: fromWatchmode(await res.json(), now) };
    if (res.status !== 404) throw new Error(`Watchmode upstream error (${res.status})`);
  }
  if (!deps.tmdbToken) throw new Error("No availability provider configured (TMDB / Watchmode)");
  const res = await deps.fetch(`${TMDB_API_BASE}/${mediaType}/${tmdbId}/watch/providers`, {
    headers: tmdbHeaders(deps.tmdbToken),
  });
  if (res.status === 404) return { source: "tmdb", providers: [] };
  if (!res.ok) throw new Error(`TMDB upstream error (${res.status})`);
  const body = await res.json();
  return { source: "tmdb", providers: fromTmdb(body.results?.[country]) };
}

export async function handleAvailability(req: Request, deps: AvailabilityDeps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const url = new URL(req.url);
  const tmdbId = Number(url.searchParams.get("tmdb_id"));
  const mediaType = parseMediaType(url.searchParams.get("media_type"));
  const country = (url.searchParams.get("country") || "US").toUpperCase();
  if (!Number.isInteger(tmdbId) || tmdbId <= 0 || !mediaType || !/^[A-Z]{2}$/.test(country)) {
    return json({ error: "Required query params: tmdb_id, media_type ('movie' | 'tv'); optional country (ISO-2)" }, 400);
  }

  const now = deps.now?.() ?? new Date();
  try {
    if (deps.store) {
      const cached = await deps.store.getAvailability(tmdbId, mediaType, country);
      const fresh = cached.length > 0 && cached.every((r) =>
        r.updated_at && now.getTime() - new Date(r.updated_at).getTime() < CACHE_TTL_HOURS * 3_600_000
      );
      if (fresh) {
        return json(
          { tmdb_id: tmdbId, media_type: mediaType, country_code: country, source: "cache", providers: fromRows(cached) },
          200,
          { "X-Cache": "HIT" },
        );
      }
    }

    const { source, providers } = await fetchAvailability(tmdbId, mediaType, country, deps);

    if (deps.store) {
      await deps.store.replaceAvailability(
        tmdbId,
        mediaType,
        country,
        providers.map((p) => ({
          title_id: tmdbId,
          media_type: mediaType,
          platform_id: p.platform_id,
          country_code: country,
          monetization_type: p.monetization_type,
          deep_link_url: p.web_url,
          available_until: p.available_until,
          is_leaving_soon: p.is_leaving_soon,
        })),
      ).catch((e) => console.error("availability cache", e)); // e.g. title not yet in `titles`
    }

    return json({ tmdb_id: tmdbId, media_type: mediaType, country_code: country, source, providers }, 200, {
      "X-Cache": "MISS",
    });
  } catch (err) {
    return json({ error: "Failed to load streaming availability", details: String(err) }, 502);
  }
}
