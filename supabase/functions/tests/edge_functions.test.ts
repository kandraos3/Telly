// BE-104 / BE-402 / BE-403 / BE-605 edge-function unit tests.
// Run: deno test --allow-env supabase/functions/tests/
import { assert, assertEquals } from "jsr:@std/assert@1";
import { handleSearch } from "../tmdb-search/handler.ts";
import { handleDetails } from "../tmdb-details/handler.ts";
import { handleAvailability } from "../streaming-availability/handler.ts";
import { handleCatalogSync } from "../streaming-catalog-sync/handler.ts";
import { handleScheduler, monthStart } from "../challenge-scheduler/handler.ts";
import { platformFromName } from "../_shared/providers.ts";
import { isAuthenticatedUserRequest, isServiceRoleRequest } from "../_shared/http.ts";
import { handleTitleRelated, listItemToTitleRow } from "../title-related/handler.ts";
import { handleSeason, normalizeEpisodes } from "../tmdb-season/handler.ts";
import { handleTrackingRefresh, MAX_SHOWS_PER_RUN, type RefreshDeps, TIME_BUDGET_MS } from "../tracking-refresh/handler.ts";
import { genreNames } from "../_shared/genres.ts";
import {
  fakeFetch,
  jsonResponse,
  MemoryEpisodeStore,
  MemoryExploreStore,
  MemoryStore,
  MemoryTrackingStore,
  RecordedCall,
} from "./fakes.ts";

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

Deno.test("tmdb-details: series cast comes from aggregate_credits across all seasons (BE-DETAIL-01)", async () => {
  const calls: RecordedCall[] = [];
  const fetch = fakeFetch({
    "/tv/1396": () =>
      jsonResponse({
        id: 1396,
        name: "Breaking Bad",
        credits: { cast: [{ name: "Latest Season Only", character: "Cameo" }], crew: [] },
        aggregate_credits: {
          cast: [
            { name: "Aaron Paul", order: 1, profile_path: "/aaron.jpg", roles: [{ character: "Jesse Pinkman" }] },
            { name: "Bryan Cranston", order: 0, profile_path: "/bryan.jpg", roles: [{ character: "Walter White" }] },
          ],
        },
      }),
  }, calls);
  const body = await (await handleDetails(req("/?id=1396&media_type=tv"), { fetch, tmdbToken: "t", store: null })).json();
  assert(calls[0].url.includes("append_to_response=credits,aggregate_credits"));
  assertEquals(body.cast, [
    { name: "Bryan Cranston", character: "Walter White", profile_path: "/bryan.jpg" },
    { name: "Aaron Paul", character: "Jesse Pinkman", profile_path: "/aaron.jpg" },
  ]);
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

// ---------------------------------------------------------------------------- tmdb-details: collections (#140)
const darkKnight = () =>
  jsonResponse({
    id: 155,
    title: "The Dark Knight",
    release_date: "2008-07-16",
    genres: [{ name: "Action" }, { name: "Crime" }],
    production_companies: [{ name: "Warner Bros. Pictures" }, { name: "Syncopy" }],
    belongs_to_collection: { id: 263, name: "The Dark Knight Collection" },
    credits: { cast: [], crew: [{ job: "Director", name: "Christopher Nolan" }] },
  });
const darkKnightCollection = () =>
  jsonResponse({
    id: 263,
    name: "The Dark Knight Collection",
    poster_path: "/dk.jpg",
    parts: [
      { id: 49026, title: "The Dark Knight Rises", release_date: "2012-07-17", poster_path: "/dkr.jpg" },
      { id: 272, title: "Batman Begins", release_date: "2005-06-10" },
      { id: 155, title: "The Dark Knight", release_date: "2008-07-16" },
      { id: 999001, title: "Unannounced Sequel", release_date: "" },
    ],
  });

Deno.test("tmdb-details: films store their collection, companies and metadata version (#140)", async () => {
  const store = new MemoryStore();
  const calls: RecordedCall[] = [];
  const fetch = fakeFetch({ "/collection/263": darkKnightCollection, "/movie/155": darkKnight }, calls);
  const res = await handleDetails(req("/?id=155&media_type=movie"), {
    fetch,
    tmdbToken: "t",
    store,
    now: () => new Date("2026-10-07T12:00:00Z"),
  });
  assertEquals(res.status, 200);
  const title = store.titles.find((t) => t.id === 155 && t.metadata_version === 2)!;
  assertEquals(title.collection_id, 263);
  assertEquals(title.production_companies, ["Warner Bros. Pictures", "Syncopy"]);
  assertEquals(title.tv_type, null);

  // A never-fetched collection is cached, its parts stored, and only released parts count.
  assertEquals(store.collections.length, 1);
  const collection = store.collections[0];
  assertEquals(collection.part_ids, [272, 155, 49026, 999001]);
  assertEquals(collection.released_part_ids, [272, 155, 49026]);
  assert(store.titles.some((t) => t.id === 49026 && t.collection_id === 263 && t.title === "The Dark Knight Rises"));
});

Deno.test("tmdb-details: a fresh collection is not refetched; a week-old one is", async () => {
  const store = new MemoryStore();
  const calls: RecordedCall[] = [];
  const fetch = fakeFetch({ "/collection/263": darkKnightCollection, "/movie/155": darkKnight }, calls);
  const deps = { fetch, tmdbToken: "t", store, now: () => new Date("2026-10-07T12:00:00Z") };

  store.collectionFetched[263] = "2026-10-05T12:00:00Z";
  await handleDetails(req("/?id=155&media_type=movie"), deps);
  assertEquals(calls.filter((c) => c.url.includes("/collection/")).length, 0);

  store.collectionFetched[263] = "2026-09-29T12:00:00Z";
  await handleDetails(req("/?id=155&media_type=movie"), deps);
  assertEquals(calls.filter((c) => c.url.includes("/collection/")).length, 1);
});

Deno.test("tmdb-details: series store their TMDB type and no collection", async () => {
  const store = new MemoryStore();
  const fetch = fakeFetch({
    "/tv/87108": () => jsonResponse({ id: 87108, name: "Chernobyl", type: "Miniseries", networks: [{ name: "HBO" }] }),
  });
  await handleDetails(req("/?id=87108&media_type=tv"), { fetch, tmdbToken: "t", store });
  assertEquals(store.titles[0].tv_type, "Miniseries");
  assertEquals(store.titles[0].collection_id, null);
});

Deno.test("tmdb-details maintenance: service role only; backfills titles and refreshes stale collections", async () => {
  const store = new MemoryStore();
  store.needingDetails = [{ id: 155, media_type: "movie" }];
  store.staleCollectionIds = [263];
  store.collectionFetched[263] = "2026-10-07T00:00:00Z"; // fresh, so the details call doesn't refetch it
  const fetch = fakeFetch({ "/collection/263": darkKnightCollection, "/movie/155": darkKnight });
  const deps = { fetch, tmdbToken: "t", store, serviceRoleKey: "srk", now: () => new Date("2026-10-07T12:00:00Z") };

  const denied = await handleDetails(req("/", { method: "POST", headers: { Authorization: "Bearer nope" } }), deps);
  assertEquals(denied.status, 401);

  const res = await handleDetails(
    req("/", { method: "POST", headers: { Authorization: "Bearer srk" }, body: JSON.stringify({ limit: 10 }) }),
    deps,
  );
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { titles: 1, collections: 1, failures: [] });
  assert(store.titles.some((t) => t.id === 155 && t.metadata_version === 2));
  assertEquals(store.collections.length, 1);
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

// ---------------------------------------------------------------------------- service-role auth (#152)
function fakeJwt(claims: Record<string, unknown>): string {
  const enc = (o: unknown) => btoa(JSON.stringify(o)).replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
  return `${enc({ alg: "HS256", typ: "JWT" })}.${enc(claims)}.signature`;
}

Deno.test("scheduled functions accept the env key or a gateway-verified service_role JWT", () => {
  const withAuth = (h?: string) =>
    new Request("http://edge.local/", { method: "POST", headers: h ? { Authorization: h } : {} });
  assertEquals(isServiceRoleRequest(withAuth("Bearer srk"), "srk"), true);
  assertEquals(isServiceRoleRequest(withAuth(`Bearer ${fakeJwt({ role: "service_role" })}`), "a-different-env-key"), true);
  assertEquals(isServiceRoleRequest(withAuth(`Bearer ${fakeJwt({ role: "anon" })}`), "srk"), false);
  assertEquals(isServiceRoleRequest(withAuth(`Bearer ${fakeJwt({ role: "authenticated", sub: "u" })}`), "srk"), false);
  assertEquals(isServiceRoleRequest(withAuth("Bearer not-a-jwt"), "srk"), false);
  assertEquals(isServiceRoleRequest(withAuth(), "srk"), false);
  assertEquals(isServiceRoleRequest(withAuth("Bearer "), undefined), false);
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

// ---------------------------------------------------------------------------- challenge-scheduler (#143)
Deno.test("challenge-scheduler: service role only", async () => {
  const res = await handleScheduler(new Request("http://edge.local/", { method: "POST" }), {
    rpc: () => Promise.resolve(0),
    serviceRoleKey: "srk",
  });
  assertEquals(res.status, 401);
});

Deno.test("challenge-scheduler: schedules this month and next, then expires featured flags", async () => {
  const calls: [string, Record<string, unknown> | undefined][] = [];
  const res = await handleScheduler(
    new Request("http://edge.local/", { method: "POST", headers: { Authorization: "Bearer srk" } }),
    {
      rpc: (fn, args) => {
        calls.push([fn, args]);
        return Promise.resolve(fn === "expire_featured_challenges" ? 1 : 2);
      },
      serviceRoleKey: "srk",
      now: () => new Date("2026-12-25T06:00:00Z"),
    },
  );
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { created: { "2026-12-01": 2, "2027-01-01": 2 }, expired: 1 });
  assertEquals(calls, [
    ["schedule_calendar_challenges", { p_month: "2026-12-01" }],
    ["schedule_calendar_challenges", { p_month: "2027-01-01" }],
    ["expire_featured_challenges", undefined],
  ]);
});

Deno.test("challenge-scheduler: monthStart rolls over the year", () => {
  assertEquals(monthStart(new Date("2026-12-31T23:59:59Z"), 1), "2027-01-01");
  assertEquals(monthStart(new Date("2026-03-15T00:00:00Z")), "2026-03-01");
});

// ---------------------------------------------------------------------------- title-related (#177)
const NOW = new Date("2026-10-08T12:00:00Z");
const userAuth = () => ({ Authorization: `Bearer ${fakeJwt({ role: "authenticated", sub: "u1" })}` });
const post = (body: unknown, headers: Record<string, string>) =>
  req("/", { method: "POST", headers: { ...headers, "Content-Type": "application/json" }, body: JSON.stringify(body) });
const recs = (ids: number[], extra: Record<string, unknown> = {}) =>
  jsonResponse({
    results: ids.map((id) => ({ id, title: `Film ${id}`, genre_ids: [18, 53], vote_average: 7.26, vote_count: 410, ...extra })),
  });

Deno.test("genre ids map to the names titles.genres stores, per media type", () => {
  assertEquals(genreNames([878, 18, 999999], "movie"), ["Science Fiction", "Drama"]);
  assertEquals(genreNames([10765, 10759], "tv"), ["Sci-Fi & Fantasy", "Action & Adventure"]);
  assertEquals(genreNames([10765], "movie"), []);
});

Deno.test("title-related: a list item becomes a minimal titles row with votes and genres", () => {
  const row = listItemToTitleRow(
    {
      id: 1429, name: "Attack on Titan", first_air_date: "2013-04-07", genre_ids: [16, 10759], origin_country: ["JP"],
      vote_average: 8.66, vote_count: 7000, popularity: 99.5, poster_path: "/p.jpg",
    },
    "tv",
  )!;
  assertEquals(row.title, "Attack on Titan");
  assertEquals(row.release_date, "2013-04-07");
  assertEquals(row.genres, ["Animation", "Action & Adventure"]);
  assertEquals(row.tmdb_vote_average, 8.7);
  assertEquals(row.tmdb_vote_count, 7000);
  assertEquals(row.is_anime, true);
  assertEquals(row.backdrop_path, null);
  assertEquals(listItemToTitleRow({ id: "x" }, "movie"), null);
});

Deno.test("title-related: a user's stale seeds are fetched, fresh ones skipped", async () => {
  const store = new MemoryExploreStore();
  store.relatedFetched["movie:157336"] = "2026-10-01T00:00:00Z"; // 7 days old: fresh
  store.relatedFetched["movie:496243"] = "2026-09-01T00:00:00Z"; // 37 days old: stale
  const calls: RecordedCall[] = [];
  const fetch = fakeFetch({
    "/movie/496243/recommendations": () => recs([11, 12, 496243, 11]),
    "/movie/129/recommendations": () => recs([]),
  }, calls);
  const res = await handleTitleRelated(post({ seed_ids: [157336, 496243, 129], media_type: "movie" }, userAuth()), {
    fetch, tmdbToken: "t", store, now: () => NOW,
  });
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { refreshed: [496243, 129], fresh: [157336], failures: [] });
  assertEquals(calls.length, 2);
  assert(calls[0].url.includes("page=1"));
  // The seed itself and duplicates are dropped; positions follow TMDB order.
  assertEquals(store.related.get("movie:496243"), [{ related_id: 11, position: 1 }, { related_id: 12, position: 2 }]);
  assertEquals(store.titles.map((t) => t.id), [11, 12]);
  assertEquals(store.titles[0].genres, ["Drama", "Thriller"]);
  // No recommendations still logs the fetch, so it isn't retried every time.
  assertEquals(store.related.get("movie:129"), []);
});

Deno.test("title-related: a seed unknown to TMDB is logged as an empty fetch", async () => {
  const store = new MemoryExploreStore();
  const res = await handleTitleRelated(post({ seed_ids: [42], media_type: "tv" }, userAuth()), {
    fetch: fakeFetch({}), tmdbToken: "t", store, now: () => NOW,
  });
  assertEquals((await res.json()).refreshed, [42]);
  assertEquals(store.related.get("tv:42"), []);
});

Deno.test("title-related: bad user requests are rejected", async () => {
  const deps = { fetch: fakeFetch({}), tmdbToken: "t", store: new MemoryExploreStore(), serviceRoleKey: "srk", now: () => NOW };
  for (const body of [
    { seed_ids: [1, 2, 3, 4, 5, 6], media_type: "movie" },
    { seed_ids: [], media_type: "movie" },
    { seed_ids: [1], media_type: "book" },
    { seed_ids: [-1], media_type: "tv" },
    { seed_ids: ["1"], media_type: "tv" },
  ]) {
    assertEquals((await handleTitleRelated(post(body, userAuth()), deps)).status, 400, JSON.stringify(body));
  }
  const anon = { Authorization: `Bearer ${fakeJwt({ role: "anon" })}` };
  assertEquals((await handleTitleRelated(post({ seed_ids: [1], media_type: "tv" }, anon), deps)).status, 401);
  assertEquals((await handleTitleRelated(req("/"), deps)).status, 405);
  assertEquals((await handleTitleRelated(post({}, userAuth()), { ...deps, tmdbToken: undefined })).status, 500);
});

Deno.test("title-related: a rate-limited user request answers 429", async () => {
  const fetch = fakeFetch({ "/recommendations": () => new Response("slow down", { status: 429 }) });
  const res = await handleTitleRelated(post({ seed_ids: [7], media_type: "movie" }, userAuth()), {
    fetch, tmdbToken: "t", store: new MemoryExploreStore(), now: () => NOW,
  });
  assertEquals(res.status, 429);
});

Deno.test("title-related: the scheduler refreshes stale trending, then stale seeds", async () => {
  const store = new MemoryExploreStore();
  store.trendingFetched.movie = "2026-10-08T09:00:00Z"; // 3 h old: fresh
  store.trendingFetched.tv = "2026-10-08T01:00:00Z"; // 11 h old: stale
  store.stale = [{ seed_id: 1396, media_type: "tv" }, { seed_id: 155, media_type: "movie" }];
  const calls: RecordedCall[] = [];
  const fetch = fakeFetch({
    "/trending/tv/week": () =>
      jsonResponse({
        results: [
          { id: 66732, media_type: "tv", name: "Stranger Things", genre_ids: [10765] },
          { id: 9, media_type: "person", name: "Someone" },
        ],
      }),
    "/tv/1396/recommendations": () => recs([60059]),
    "/movie/155/recommendations": () => new Response("down", { status: 503 }),
  }, calls);
  const res = await handleTitleRelated(post({}, { Authorization: "Bearer srk" }), {
    fetch, tmdbToken: "t", store, serviceRoleKey: "srk", now: () => NOW,
  });
  assertEquals(await res.json(), { trending: 1, seeds: 1, rate_limited: false, failures: ["movie:155 (503)"] });
  assert(!calls.some((c) => c.url.includes("/trending/movie")));
  assertEquals(store.trending.tv, [66732]); // the person is skipped
  assertEquals(store.titles.find((t) => t.id === 66732)?.genres, ["Sci-Fi & Fantasy"]);
  assertEquals(store.related.get("tv:1396"), [{ related_id: 60059, position: 1 }]);
});

Deno.test("title-related: the scheduler stops at TMDB's rate limit", async () => {
  const store = new MemoryExploreStore();
  store.stale = [{ seed_id: 1, media_type: "movie" }, { seed_id: 2, media_type: "movie" }];
  const calls: RecordedCall[] = [];
  const fetch = fakeFetch({ "/trending/movie": () => new Response("slow", { status: 429 }) }, calls);
  const res = await handleTitleRelated(post({}, { Authorization: "Bearer srk" }), {
    fetch, tmdbToken: "t", store, serviceRoleKey: "srk", now: () => NOW,
  });
  assertEquals((await res.json()).rate_limited, true);
  assertEquals(calls.length, 1);
});

Deno.test("only a signed-in user's JWT counts as a user request", () => {
  const withAuth = (h?: string) => new Request("http://edge.local/", { method: "POST", headers: h ? { Authorization: h } : {} });
  assertEquals(isAuthenticatedUserRequest(withAuth(`Bearer ${fakeJwt({ role: "authenticated", sub: "u" })}`)), true);
  assertEquals(isAuthenticatedUserRequest(withAuth(`Bearer ${fakeJwt({ role: "anon" })}`)), false);
  assertEquals(isAuthenticatedUserRequest(withAuth()), false);
});

// ---------------------------------------------------------------------------- watch tracking (#227)
const seasonPayload = () =>
  jsonResponse({
    episodes: [
      { episode_number: 1, name: "Good News About Hell", overview: "Mark leads.", still_path: "/e1.jpg", air_date: "2022-02-18", runtime: 55 },
      { episode_number: 2, name: "Half Loop", overview: "", still_path: null, air_date: "not a date", runtime: 0 },
      { episode_number: 0, name: "A bad row" },
    ],
  });

Deno.test("tmdb-season: normalizes episodes, dropping rows without a positive number", () => {
  const rows = normalizeEpisodes(
    {
      episodes: [
        { episode_number: 1, name: "x".repeat(300), overview: "o", still_path: "/s.jpg", air_date: "2022-02-18", runtime: 55 },
        { episode_number: 2, overview: "", air_date: "soon", runtime: 0 },
        { episode_number: -1 },
        { name: "no number" },
      ],
    },
    95396,
    1,
  );
  assertEquals(rows.length, 2);
  assertEquals(rows[0], {
    title_id: 95396,
    season_number: 1,
    episode_number: 1,
    name: "x".repeat(200),
    overview: "o",
    still_path: "/s.jpg",
    air_date: "2022-02-18",
    runtime_minutes: 55,
  });
  assertEquals([rows[1].name, rows[1].overview, rows[1].air_date, rows[1].runtime_minutes], [null, null, null, null]);
  assertEquals(normalizeEpisodes({}, 1, 1), []);
});

Deno.test("tmdb-season: a signed-in user's season is fetched, cached and returned", async () => {
  const calls: RecordedCall[] = [];
  const store = new MemoryEpisodeStore();
  const res = await handleSeason(req("/?id=95396&season=1", { headers: userAuth() }), {
    fetch: fakeFetch({ "/tv/95396/season/1": seasonPayload }, calls),
    tmdbToken: "t",
    store,
  });
  assertEquals(res.status, 200);
  const body = await res.json();
  assertEquals(body.season_number, 1);
  assertEquals(body.episodes.length, 2);
  assertEquals(store.rows.map((r) => r.episode_number), [1, 2]);
  assertEquals(store.rows.every((r) => r.title_id === 95396 && r.season_number === 1), true);
  assertEquals(calls.length, 1);
  assertEquals(res.headers.get("Cache-Control"), "private, max-age=3600");
});

Deno.test("tmdb-season: the service role may fetch a season too", async () => {
  const res = await handleSeason(req("/?id=1&season=2", { headers: { Authorization: "Bearer srk" } }), {
    fetch: fakeFetch({ "/tv/1/season/2": seasonPayload }),
    tmdbToken: "t",
    store: new MemoryEpisodeStore(),
    serviceRoleKey: "srk",
  });
  assertEquals(res.status, 200);
});

Deno.test("tmdb-season: rejects bad requests", async () => {
  const deps = { fetch: fakeFetch({}), tmdbToken: "t", store: new MemoryEpisodeStore(), serviceRoleKey: "srk" };
  const anon = { Authorization: `Bearer ${fakeJwt({ role: "anon" })}` };
  assertEquals((await handleSeason(req("/?id=1&season=1", { headers: anon }), deps)).status, 401);
  assertEquals((await handleSeason(req("/?id=1&season=1"), deps)).status, 401);
  for (const q of ["id=1&season=0", "id=1&season=-1", "id=1&season=x", "id=1&season=1.5", "id=0&season=1", "season=1"]) {
    assertEquals((await handleSeason(req(`/?${q}`, { headers: userAuth() }), deps)).status, 400, q);
  }
  assertEquals((await handleSeason(req("/?id=1&season=1", { method: "POST", headers: userAuth() }), deps)).status, 405);
  assertEquals((await handleSeason(req("/?id=1&season=1", { headers: userAuth() }), { ...deps, tmdbToken: undefined })).status, 500);
  assertEquals((await handleSeason(req("/", { method: "OPTIONS" }), deps)).status, 200);
});

Deno.test("tmdb-season: TMDB 404, 429 and errors are passed on", async () => {
  const missing = await handleSeason(req("/?id=1&season=9", { headers: userAuth() }), {
    fetch: fakeFetch({}),
    tmdbToken: "t",
    store: new MemoryEpisodeStore(),
  });
  assertEquals(missing.status, 404);
  const slow = await handleSeason(req("/?id=1&season=1", { headers: userAuth() }), {
    fetch: fakeFetch({ "/season/": () => new Response("slow", { status: 429 }) }),
    tmdbToken: "t",
    store: new MemoryEpisodeStore(),
  });
  assertEquals(slow.status, 429);
  assertEquals(slow.headers.get("Retry-After"), "5");
  const broken = await handleSeason(req("/?id=1&season=1", { headers: userAuth() }), {
    fetch: fakeFetch({ "/season/": () => new Response("boom", { status: 500 }) }),
    tmdbToken: "t",
    store: new MemoryEpisodeStore(),
  });
  assertEquals(broken.status, 502);
});

const srkPost = () => req("/", { method: "POST", headers: { Authorization: "Bearer srk" } });
const tvDetails = (id: number) =>
  jsonResponse({
    id,
    name: `Show ${id}`,
    status: "Returning Series",
    number_of_seasons: 2,
    seasons: [
      { season_number: 1, episode_count: 2, air_date: "2022-01-01" },
      { season_number: 2, episode_count: 2, air_date: "2025-01-01" },
    ],
  });
const refreshDeps = (over: Partial<RefreshDeps> = {}) => {
  const catalog = new MemoryStore();
  const episodes = new MemoryEpisodeStore();
  const tracking = new MemoryTrackingStore();
  const deps: RefreshDeps = {
    fetch: fakeFetch({
      "/tv/11/season/2": seasonPayload,
      "/tv/12/season/1": seasonPayload,
      "/tv/11?": () => tvDetails(11),
      "/tv/12?": () => tvDetails(12),
    }),
    tmdbToken: "t",
    catalog,
    episodes,
    tracking,
    serviceRoleKey: "srk",
    now: () => NOW,
    ...over,
  };
  return { catalog, episodes, tracking, deps };
};

Deno.test("tracking-refresh: service role POST only", async () => {
  const { deps } = refreshDeps();
  assertEquals((await handleTrackingRefresh(req("/", { method: "POST" }), deps)).status, 401);
  assertEquals((await handleTrackingRefresh(req("/", { method: "POST", headers: userAuth() }), deps)).status, 401);
  assertEquals((await handleTrackingRefresh(req("/", { headers: { Authorization: "Bearer srk" } }), deps)).status, 405);
  assertEquals((await handleTrackingRefresh(srkPost(), { ...deps, tmdbToken: undefined })).status, 500);
});

Deno.test("tracking-refresh: refreshes each show and its seasons, then flips new episodes", async () => {
  const { deps, catalog, episodes, tracking } = refreshDeps();
  tracking.shows = [11, 12];
  tracking.seasons = { 11: [2], 12: [1] };
  tracking.flipped = 3;
  const res = await handleTrackingRefresh(srkPost(), deps);
  assertEquals(res.status, 200);
  assertEquals(await res.json(), {
    shows: 2,
    seasons: 2,
    flipped: 3,
    rateLimited: false,
    timedOut: false,
    includeEnded: false,
    failures: [],
  });
  assertEquals(catalog.titles.map((t) => t.id), [11, 12]);
  assertEquals(catalog.seasons.length, 4);
  assertEquals(episodes.rows.length, 4, "two episodes per season, from two seasons");
  assertEquals(tracking.lastLimit, MAX_SHOWS_PER_RUN);
  assertEquals(tracking.flipRuns, 1);
});

Deno.test("tracking-refresh: ended shows are only included on Mondays", async () => {
  const thursday = refreshDeps(); // NOW is Thursday 2026-10-08
  await handleTrackingRefresh(srkPost(), thursday.deps);
  assertEquals(thursday.tracking.lastIncludeEnded, false);
  const monday = refreshDeps({ now: () => new Date("2026-10-05T05:23:00Z") });
  const res = await handleTrackingRefresh(srkPost(), monday.deps);
  assertEquals(monday.tracking.lastIncludeEnded, true);
  assertEquals((await res.json()).includeEnded, true);
});

Deno.test("tracking-refresh: a TMDB rate limit stops the fetching but still flips", async () => {
  const { deps, tracking, episodes } = refreshDeps();
  tracking.shows = [11, 12];
  tracking.seasons = { 11: [2], 12: [1] };
  const limited = {
    ...deps,
    fetch: fakeFetch({
      "/tv/11?": () => tvDetails(11),
      "/tv/11/season/2": () => new Response("slow", { status: 429 }),
      "/tv/12?": () => tvDetails(12),
    }),
  };
  const body = await (await handleTrackingRefresh(srkPost(), limited)).json();
  assertEquals(body.rateLimited, true);
  assertEquals(body.shows, 1, "the second show is never reached");
  assertEquals(episodes.rows.length, 0);
  assertEquals(tracking.flipRuns, 1);
});

Deno.test("tracking-refresh: a failing show is recorded and the run carries on", async () => {
  const { deps, tracking } = refreshDeps();
  tracking.shows = [13, 12];
  tracking.seasons = { 12: [1] };
  const body = await (await handleTrackingRefresh(srkPost(), deps)).json();
  assertEquals(body.failures, ["tv:13 (404)"]);
  assertEquals(body.shows, 1);
  assertEquals(body.seasons, 1);
  assertEquals(tracking.flipRuns, 1);
});

Deno.test("tracking-refresh: the time budget stops the run cleanly", async () => {
  let ticks = 0;
  // Every look at the clock is 60% of the budget later, so the second show starts past it.
  const clock = () => new Date(NOW.getTime() + ticks++ * (TIME_BUDGET_MS * 0.6));
  const { deps, tracking } = refreshDeps({ now: clock });
  tracking.shows = [11, 12];
  tracking.seasons = { 11: [2], 12: [1] };
  const body = await (await handleTrackingRefresh(srkPost(), deps)).json();
  assertEquals(body.timedOut, true);
  assertEquals(body.shows, 1);
  assertEquals(tracking.flipRuns, 1);
});

Deno.test("tracking-refresh: a database failure answers 500", async () => {
  const { deps, tracking } = refreshDeps();
  tracking.showsToRefresh = () => Promise.reject(new Error("db down"));
  const res = await handleTrackingRefresh(srkPost(), deps);
  assertEquals(res.status, 500);
});
