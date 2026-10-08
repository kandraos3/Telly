// TMDB genre ids → names, as /genre/movie/list and /genre/tv/list return them (#177).
// List endpoints (recommendations, trending) return only `genre_ids`, while `titles.genres`
// stores names (the names tmdb-details writes), so the two must match.
import type { MediaType } from "./http.ts";

const MOVIE_GENRES: Record<number, string> = {
  28: "Action",
  12: "Adventure",
  16: "Animation",
  35: "Comedy",
  80: "Crime",
  99: "Documentary",
  18: "Drama",
  10751: "Family",
  14: "Fantasy",
  36: "History",
  27: "Horror",
  10402: "Music",
  9648: "Mystery",
  10749: "Romance",
  878: "Science Fiction",
  10770: "TV Movie",
  53: "Thriller",
  10752: "War",
  37: "Western",
};

const TV_GENRES: Record<number, string> = {
  10759: "Action & Adventure",
  16: "Animation",
  35: "Comedy",
  80: "Crime",
  99: "Documentary",
  18: "Drama",
  10751: "Family",
  10762: "Kids",
  9648: "Mystery",
  10763: "News",
  10764: "Reality",
  10765: "Sci-Fi & Fantasy",
  10766: "Soap",
  10767: "Talk",
  10768: "War & Politics",
  37: "Western",
};

/** Names for [ids] in TMDB's order; unknown ids are dropped. */
export function genreNames(ids: readonly number[], mediaType: MediaType): string[] {
  const table = mediaType === "movie" ? MOVIE_GENRES : TV_GENRES;
  return ids.map((id) => table[id]).filter((name): name is string => name !== undefined);
}
