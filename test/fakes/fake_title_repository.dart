import 'package:telly_app/features/logging/data/title_repository.dart';
import 'package:telly_app/features/logging/domain/title_search_result.dart';

/// In-memory [TitleRepository] for widget tests (FE-603/FE-604).
class FakeTitleRepository implements TitleRepository {
  final queries = <String>[];
  bool offline = false;

  static const catalog = [
    TitleSearchResult(id: 136315, mediaType: 'tv', title: 'The Bear', releaseYear: '2022'),
    TitleSearchResult(id: 27205, mediaType: 'movie', title: 'Inception', releaseYear: '2010'),
  ];

  TitleCredits credits = const TitleCredits(
    director: 'Christopher Storer',
    members: [
      TitleCastMember(name: 'Jeremy Allen White', character: 'Carmy Berzatto'),
      TitleCastMember(name: 'Ayo Edebiri', character: 'Sydney Adamu'),
    ],
  );

  @override
  Future<TitleCredits> fetchCredits(int id, String mediaType, {Duration? timeout}) async => credits;

  @override
  Future<TitleSearchOutcome> search(String query) async {
    queries.add(query);
    final q = query.toLowerCase();
    return TitleSearchOutcome(
      catalog.where((t) => t.title.toLowerCase().contains(q)).toList(),
      fromLocalCache: offline,
    );
  }
}
