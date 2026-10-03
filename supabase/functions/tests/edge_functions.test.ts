// BE-104 / BE-402 / BE-403 / BE-605 edge-function unit tests.
// Run: deno test --allow-env supabase/functions/tests/
import { assert, assertEquals } from "jsr:@std/assert@1";
import { handleSearch } from "../tmdb-search/handler.ts";
import { handleDetails } from "../tmdb-details/handler.ts";
import { handleAvailability } from "../streaming-availability/handler.ts";
import { handleCatalogSync } from "../streaming-catalog-sync/handler.ts";
import { platformFromName } from "../_shared/providers.ts";
import { fakeFetch, jsonResponse, MemoryStore, RecordedCall } from "./fakes.ts";

const req = (path: string, init?: RequestInit) => new Request(`http://edge.local${path}`, init);

// ---------------------------------------------------------------------------- tmdb-search
Deno.test("tmdb-search: 'Oppenheimer' normalizes to media_type movie and caches into titles", async () => {
  const store = new MemoryStore();
  const fetch = fakeFetch({
    "/search/multi": () =>
      jsonResponse({
        page: 1,
        total_pages: 1,
        results: [
          { id: 872585, media_type: "movie", title: "Oppenheimer", release_date: "2023-07-19", popularity: 99, genre_ids: [18] },
          { id: 1, media_type: "person", name: "Cillian Murphy" },
          { id: 1429, media_type: "tv", name: "Attack on Titan", first_air_date: "2013-04-07", genre_ids: [16], origin_country: ["JP"] },
        ],
      }),
  });
  const res = await handleSearch(req("/?query=Oppenheimer"), { fetch, tmdbToken: "t", store });
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("Cache-Control"), "public, max-age=86400, s-maxage=604800");
  const body = await res.json();
  assertEquals(body.results.length, 2, "person results are dropped");
  assertEquals(body.results[0].media_type, "movie");
  assertEquals(body.results[0].release_year, "2023");
  assertEquals(body.results[1].is_anime, true);
  assertEquals(store.titles.map((t) => `${t.media_type}:${t.id}`), ["movie:872585", "tv:1429"]);
});

Deno.test("tmdb-search: upstream 429 is surfaced as 429 with Retry-After", async () => {
  const fetch = fakeFetch({ "/search/multi": () => new Response("", { status: 429 }) });
  const res = await handleSearch(req("/?query=x"), { fetch, tmdbToken: "t", store: null });
  assertEquals(res.status, 429);
  assertEquals(res.headers.get("Retry-After"), "5");
});

Deno.test("tmdb-search: missing query → 400; missing token → 500", async () => {
  assertEquals((await handleSearch(req("/"), { fetch: fakeFetch({}), tmdbToken: "t", store: null })).status, 400);
  assertEquals((await handleSearch(req("/?query=x"), { fetch: fakeFetch({}), tmdbToken: undefined, store: null })).status, 500);
});

// ---------------------------------------------------------------------------- tmdb-details
Deno.test("tmdb-details: tv details upsert title + seasons (specials skipped) and expose cast/creators", async () => {
  const store = new MemoryStore();
  const calls: RecordedCall[] = [];
  const fetch = fakeFetch({
    "/tv/95396": () =>
      jsonResponse({
        id: 95396,
        name: "Severance",
        first_air_date: "2022-02-18",
        status: "Returning Series",
        number_of_seasons: 2,
        number_of_episodes: 19,
        networks: [{ name: "Apple TV+" }],
        created_by: [{ name: "Dan Erickson" }],
        genres: [{ name: "Drama" }, { name: "Mystery" }],
        episode_run_time: [55],
        seasons: [
          { season_number: 0, name: "Specials", episode_count: 1 },
          { season_number: 1, name: "Season 1", episode_count: 9, air_date: "2022-02-18" },
          { season_number: 2, name: "Season 2", episode_count: 10, air_date: "2025-01-17" },
        ],
        credits: { cast: [{ name: "Adam Scott", character: "Mark Scout" }], crew: [] },
      }),
  }, calls);
  const res = await handleDetails(req("/?id=95396&media_type=tv"), { fetch, tmdbToken: "t", store });
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.network, "Apple TV+");
  assertEquals(body.creators, ["Dan Erickson"]);
  assertEquals(body.cast[0], { name: "Adam Scott", character: "Mark Scout", profile_path: null });
  assertEquals(body.seasons.length, 2);
  assert(calls[0].url.includes("append_to_response=credits"));
  assertEquals(store.titles[0].media_type, "tv");
  assertEquals(store.titles[0].runtime_minutes, null, "series runtime is per-episode, not stored as movie runtime");
  assertEquals(store.seasons.map((s) => s.season_number), [1, 2]);
});

Deno.test("tmdb-details: movie details expose director for FE-204 auto-tagging", async () => {
  const fetch = fakeFetch({
    "/movie/872585": () =>
      jsonResponse({
        id: 872585,
        title: "Oppenheimer",
        runtime: 180,
        release_date: "2023-07-19",
        genres: [{ name: "Drama" }],
        credits: { cast: [], crew: [{ job: "Director", name: "Christopher Nolan" }] },
      }),
  });
  const body = await (await handleDetails(req("/?id=872585&media_type=movie"), { fetch, tmdbToken: "t", store: null })).json();
  assertEquals(body.director, "Christopher Nolan");
  assertEquals(body.runtime_minutes, 180);
  assertEquals(body.seasons, []);
});

Deno.test("tmdb-details: bad params → 400; unknown title → 404", async () => {
  assertEquals((await handleDetails(req("/?id=1&media_type=anime"), { fetch: fakeFetch({}), tmdbToken: "t", store: null })).status, 400);
  assertEquals((await handleDetails(req("/?id=7&media_type=tv"), { fetch: fakeFetch({}), tmdbToken: "t", store: null })).status, 404);
});

// ---------------------------------------------------------------------------- streaming-availability
Deno.test("availability: Severance via TMDB providers maps to apple_tv_plus and is cached", async () => {
  const store = new MemoryStore();
  const fetch = fakeFetch({
    "/tv/95396/watch/providers": () =>
      jsonResponse({
        results: {
          US: {
            link: "https://www.themoviedb.org/tv/95396/watch",
            flatrate: [{ provider_id: 350, provider_name: "Apple TV Plus" }],
            buy: [{ provider_id: 2, provider_name: "Apple TV" }],
          },
        },
      }),
  });
  const deps = { fetch, tmdbToken: "t", watchmodeKey: undefined, store };
  const first = await handleAvailability(req("/?tmdb_id=95396&media_type=tv"), deps);
  const body = await first.json();
  assertEquals(first.headers.get("X-Cache"), "MISS");
  assertEquals(body.source, "tmdb");
  assertEquals(body.providers.map((p: { platform_id: string }) => p.platform_id), ["apple_tv_plus"]);
  assertEquals(body.providers[0].web_url, "https://www.themoviedb.org/tv/95396/watch");

  const second = await handleAvailability(req("/?tmdb_id=95396&media_type=tv"), deps);
  assertEquals(second.headers.get("X-Cache"), "HIT");
  assertEquals((await second.json()).source, "cache");
});

Deno.test("availability: Watchmode preferred when configured; native links and leaving-soon flag", async () => {
  const fetch = fakeFetch({
    "api.watchmode.com/v1/title/tv-1396/sources": () =>
      jsonResponse([
        { name: "Netflix", type: "sub", region: "US", web_url: "https://www.netflix.com/title/70143836", ios_url: "nflx://www.netflix.com/title/70143836", endDate: "2026-10-05" },
        { name: "Paramount+ Apple TV Channel", type: "sub", web_url: "x" },
        { name: "Amazon", type: "buy", web_url: "https://amazon.com/x" },
      ]),
  });
  const res = await handleAvailability(req("/?tmdb_id=1396&media_type=tv"), {
    fetch,
    tmdbToken: "t",
    watchmodeKey: "k",
    store: null,
    now: () => new Date("2026-10-03T00:00:00Z"),
  });
  const body = await res.json();
  assertEquals(body.source, "watchmode");
  assertEquals(body.providers.length, 1, "unknown stores and add-on channels are dropped");
  assertEquals(body.providers[0].ios_url, "nflx://www.netflix.com/title/70143836");
  assertEquals(body.providers[0].is_leaving_soon, true);
});

Deno.test("availability: validates params", async () => {
  const deps = { fetch: fakeFetch({}), tmdbToken: "t", watchmodeKey: undefined, store: null };
  assertEquals((await handleAvailability(req("/?media_type=tv"), deps)).status, 400);
  assertEquals((await handleAvailability(req("/?tmdb_id=1&media_type=tv&country=USA"), deps)).status, 400);
});

// ---------------------------------------------------------------------------- catalog sync
Deno.test("catalog-sync: rejects callers without the service-role key", async () => {
  const store = new MemoryStore();
  const res = await handleCatalogSync(req("/", { method: "POST" }), {
    fetch: fakeFetch({}), tmdbToken: "t", watchmodeKey: undefined, store, serviceRoleKey: "secret",
  });
  assertEquals(res.status, 401);
});

Deno.test("catalog-sync: refreshes stale watchlist titles then recomputes leaving-soon flags", async () => {
  const store = new MemoryStore();
  store.stale = [{ title_id: 95396, media_type: "tv" }];
  const fetch = fakeFetch({
    "/watch/providers": () => jsonResponse({ results: { US: { flatrate: [{ provider_id: 350 }] } } }),
  });
  const res = await handleCatalogSync(req("/", { method: "POST", headers: { Authorization: "Bearer secret" } }), {
    fetch, tmdbToken: "t", watchmodeKey: undefined, store, serviceRoleKey: "secret",
  });
  const body = await res.json();
  assertEquals(body.status, "success");
  assertEquals(body.refreshed, 1);
  assertEquals(store.availability[0].platform_id, "apple_tv_plus");
  assertEquals(store.leavingSoonRuns, 1);
});

// ---------------------------------------------------------------------------- provider mapping
Deno.test("provider names map to streaming_platforms ids", () => {
  assertEquals(platformFromName("Max"), "max");
  assertEquals(platformFromName("HBO Max"), "max");
  assertEquals(platformFromName("Amazon Prime Video"), "prime_video");
  assertEquals(platformFromName("Criterion Channel"), "criterion");
  assertEquals(platformFromName("Apple TV+"), "apple_tv_plus");
  assertEquals(platformFromName("Apple TV"), null, "the Apple TV store is not an Apple TV+ subscription");
  assertEquals(platformFromName("Paramount Plus Apple TV Channel"), null);
  assertEquals(platformFromName("Maxdome"), null);
});
