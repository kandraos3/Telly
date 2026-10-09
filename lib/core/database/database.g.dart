// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
mixin _$LocalRankingDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalRankingsTable get localRankings => attachedDatabase.localRankings;
  LocalRankingDaoManager get managers => LocalRankingDaoManager(this);
}

class LocalRankingDaoManager {
  final _$LocalRankingDaoMixin _db;
  LocalRankingDaoManager(this._db);
  $$LocalRankingsTableTableManager get localRankings =>
      $$LocalRankingsTableTableManager(_db.attachedDatabase, _db.localRankings);
}

mixin _$PendingMutationDaoMixin on DatabaseAccessor<AppDatabase> {
  $PendingMutationsTable get pendingMutations =>
      attachedDatabase.pendingMutations;
  PendingMutationDaoManager get managers => PendingMutationDaoManager(this);
}

class PendingMutationDaoManager {
  final _$PendingMutationDaoMixin _db;
  PendingMutationDaoManager(this._db);
  $$PendingMutationsTableTableManager get pendingMutations =>
      $$PendingMutationsTableTableManager(
          _db.attachedDatabase, _db.pendingMutations);
}

mixin _$LocalTitleDaoMixin on DatabaseAccessor<AppDatabase> {
  $CachedTitlesTable get cachedTitles => attachedDatabase.cachedTitles;
  LocalTitleDaoManager get managers => LocalTitleDaoManager(this);
}

class LocalTitleDaoManager {
  final _$LocalTitleDaoMixin _db;
  LocalTitleDaoManager(this._db);
  $$CachedTitlesTableTableManager get cachedTitles =>
      $$CachedTitlesTableTableManager(_db.attachedDatabase, _db.cachedTitles);
}

mixin _$ExploreCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $ExploreCacheTable get exploreCache => attachedDatabase.exploreCache;
  ExploreCacheDaoManager get managers => ExploreCacheDaoManager(this);
}

class ExploreCacheDaoManager {
  final _$ExploreCacheDaoMixin _db;
  ExploreCacheDaoManager(this._db);
  $$ExploreCacheTableTableManager get exploreCache =>
      $$ExploreCacheTableTableManager(_db.attachedDatabase, _db.exploreCache);
}

mixin _$TrackingCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $TrackingCacheTable get trackingCache => attachedDatabase.trackingCache;
  TrackingCacheDaoManager get managers => TrackingCacheDaoManager(this);
}

class TrackingCacheDaoManager {
  final _$TrackingCacheDaoMixin _db;
  TrackingCacheDaoManager(this._db);
  $$TrackingCacheTableTableManager get trackingCache =>
      $$TrackingCacheTableTableManager(_db.attachedDatabase, _db.trackingCache);
}

mixin _$EpisodeCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $EpisodeCacheTable get episodeCache => attachedDatabase.episodeCache;
  EpisodeCacheDaoManager get managers => EpisodeCacheDaoManager(this);
}

class EpisodeCacheDaoManager {
  final _$EpisodeCacheDaoMixin _db;
  EpisodeCacheDaoManager(this._db);
  $$EpisodeCacheTableTableManager get episodeCache =>
      $$EpisodeCacheTableTableManager(_db.attachedDatabase, _db.episodeCache);
}

class $CachedTitlesTable extends CachedTitles
    with TableInfo<$CachedTitlesTable, CachedTitle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedTitlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mediaTypeMeta =
      const VerificationMeta('mediaType');
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
      'media_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _posterPathMeta =
      const VerificationMeta('posterPath');
  @override
  late final GeneratedColumn<String> posterPath = GeneratedColumn<String>(
      'poster_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _backdropPathMeta =
      const VerificationMeta('backdropPath');
  @override
  late final GeneratedColumn<String> backdropPath = GeneratedColumn<String>(
      'backdrop_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _overviewMeta =
      const VerificationMeta('overview');
  @override
  late final GeneratedColumn<String> overview = GeneratedColumn<String>(
      'overview', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _releaseDateMeta =
      const VerificationMeta('releaseDate');
  @override
  late final GeneratedColumn<String> releaseDate = GeneratedColumn<String>(
      'release_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _genresMeta = const VerificationMeta('genres');
  @override
  late final GeneratedColumn<String> genres = GeneratedColumn<String>(
      'genres', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _streamingServicesMeta =
      const VerificationMeta('streamingServices');
  @override
  late final GeneratedColumn<String> streamingServices =
      GeneratedColumn<String>('streaming_services', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isAnimeMeta =
      const VerificationMeta('isAnime');
  @override
  late final GeneratedColumn<bool> isAnime = GeneratedColumn<bool>(
      'is_anime', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_anime" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _totalSeasonsMeta =
      const VerificationMeta('totalSeasons');
  @override
  late final GeneratedColumn<int> totalSeasons = GeneratedColumn<int>(
      'total_seasons', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _totalEpisodesMeta =
      const VerificationMeta('totalEpisodes');
  @override
  late final GeneratedColumn<int> totalEpisodes = GeneratedColumn<int>(
      'total_episodes', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        mediaType,
        posterPath,
        backdropPath,
        overview,
        releaseDate,
        genres,
        streamingServices,
        isAnime,
        totalSeasons,
        totalEpisodes,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_titles';
  @override
  VerificationContext validateIntegrity(Insertable<CachedTitle> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('media_type')) {
      context.handle(_mediaTypeMeta,
          mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta));
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('poster_path')) {
      context.handle(
          _posterPathMeta,
          posterPath.isAcceptableOrUnknown(
              data['poster_path']!, _posterPathMeta));
    }
    if (data.containsKey('backdrop_path')) {
      context.handle(
          _backdropPathMeta,
          backdropPath.isAcceptableOrUnknown(
              data['backdrop_path']!, _backdropPathMeta));
    }
    if (data.containsKey('overview')) {
      context.handle(_overviewMeta,
          overview.isAcceptableOrUnknown(data['overview']!, _overviewMeta));
    }
    if (data.containsKey('release_date')) {
      context.handle(
          _releaseDateMeta,
          releaseDate.isAcceptableOrUnknown(
              data['release_date']!, _releaseDateMeta));
    }
    if (data.containsKey('genres')) {
      context.handle(_genresMeta,
          genres.isAcceptableOrUnknown(data['genres']!, _genresMeta));
    }
    if (data.containsKey('streaming_services')) {
      context.handle(
          _streamingServicesMeta,
          streamingServices.isAcceptableOrUnknown(
              data['streaming_services']!, _streamingServicesMeta));
    }
    if (data.containsKey('is_anime')) {
      context.handle(_isAnimeMeta,
          isAnime.isAcceptableOrUnknown(data['is_anime']!, _isAnimeMeta));
    }
    if (data.containsKey('total_seasons')) {
      context.handle(
          _totalSeasonsMeta,
          totalSeasons.isAcceptableOrUnknown(
              data['total_seasons']!, _totalSeasonsMeta));
    }
    if (data.containsKey('total_episodes')) {
      context.handle(
          _totalEpisodesMeta,
          totalEpisodes.isAcceptableOrUnknown(
              data['total_episodes']!, _totalEpisodesMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, mediaType};
  @override
  CachedTitle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedTitle(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      mediaType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_type'])!,
      posterPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}poster_path']),
      backdropPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}backdrop_path']),
      overview: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}overview']),
      releaseDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}release_date']),
      genres: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}genres']),
      streamingServices: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}streaming_services']),
      isAnime: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_anime'])!,
      totalSeasons: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_seasons']),
      totalEpisodes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_episodes']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CachedTitlesTable createAlias(String alias) {
    return $CachedTitlesTable(attachedDatabase, alias);
  }
}

class CachedTitle extends DataClass implements Insertable<CachedTitle> {
  final int id;
  final String title;
  final String mediaType;
  final String? posterPath;
  final String? backdropPath;
  final String? overview;
  final String? releaseDate;
  final String? genres;
  final String? streamingServices;
  final bool isAnime;
  final int? totalSeasons;
  final int? totalEpisodes;
  final DateTime updatedAt;
  const CachedTitle(
      {required this.id,
      required this.title,
      required this.mediaType,
      this.posterPath,
      this.backdropPath,
      this.overview,
      this.releaseDate,
      this.genres,
      this.streamingServices,
      required this.isAnime,
      this.totalSeasons,
      this.totalEpisodes,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['media_type'] = Variable<String>(mediaType);
    if (!nullToAbsent || posterPath != null) {
      map['poster_path'] = Variable<String>(posterPath);
    }
    if (!nullToAbsent || backdropPath != null) {
      map['backdrop_path'] = Variable<String>(backdropPath);
    }
    if (!nullToAbsent || overview != null) {
      map['overview'] = Variable<String>(overview);
    }
    if (!nullToAbsent || releaseDate != null) {
      map['release_date'] = Variable<String>(releaseDate);
    }
    if (!nullToAbsent || genres != null) {
      map['genres'] = Variable<String>(genres);
    }
    if (!nullToAbsent || streamingServices != null) {
      map['streaming_services'] = Variable<String>(streamingServices);
    }
    map['is_anime'] = Variable<bool>(isAnime);
    if (!nullToAbsent || totalSeasons != null) {
      map['total_seasons'] = Variable<int>(totalSeasons);
    }
    if (!nullToAbsent || totalEpisodes != null) {
      map['total_episodes'] = Variable<int>(totalEpisodes);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CachedTitlesCompanion toCompanion(bool nullToAbsent) {
    return CachedTitlesCompanion(
      id: Value(id),
      title: Value(title),
      mediaType: Value(mediaType),
      posterPath: posterPath == null && nullToAbsent
          ? const Value.absent()
          : Value(posterPath),
      backdropPath: backdropPath == null && nullToAbsent
          ? const Value.absent()
          : Value(backdropPath),
      overview: overview == null && nullToAbsent
          ? const Value.absent()
          : Value(overview),
      releaseDate: releaseDate == null && nullToAbsent
          ? const Value.absent()
          : Value(releaseDate),
      genres:
          genres == null && nullToAbsent ? const Value.absent() : Value(genres),
      streamingServices: streamingServices == null && nullToAbsent
          ? const Value.absent()
          : Value(streamingServices),
      isAnime: Value(isAnime),
      totalSeasons: totalSeasons == null && nullToAbsent
          ? const Value.absent()
          : Value(totalSeasons),
      totalEpisodes: totalEpisodes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalEpisodes),
      updatedAt: Value(updatedAt),
    );
  }

  factory CachedTitle.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedTitle(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      posterPath: serializer.fromJson<String?>(json['posterPath']),
      backdropPath: serializer.fromJson<String?>(json['backdropPath']),
      overview: serializer.fromJson<String?>(json['overview']),
      releaseDate: serializer.fromJson<String?>(json['releaseDate']),
      genres: serializer.fromJson<String?>(json['genres']),
      streamingServices:
          serializer.fromJson<String?>(json['streamingServices']),
      isAnime: serializer.fromJson<bool>(json['isAnime']),
      totalSeasons: serializer.fromJson<int?>(json['totalSeasons']),
      totalEpisodes: serializer.fromJson<int?>(json['totalEpisodes']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'mediaType': serializer.toJson<String>(mediaType),
      'posterPath': serializer.toJson<String?>(posterPath),
      'backdropPath': serializer.toJson<String?>(backdropPath),
      'overview': serializer.toJson<String?>(overview),
      'releaseDate': serializer.toJson<String?>(releaseDate),
      'genres': serializer.toJson<String?>(genres),
      'streamingServices': serializer.toJson<String?>(streamingServices),
      'isAnime': serializer.toJson<bool>(isAnime),
      'totalSeasons': serializer.toJson<int?>(totalSeasons),
      'totalEpisodes': serializer.toJson<int?>(totalEpisodes),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CachedTitle copyWith(
          {int? id,
          String? title,
          String? mediaType,
          Value<String?> posterPath = const Value.absent(),
          Value<String?> backdropPath = const Value.absent(),
          Value<String?> overview = const Value.absent(),
          Value<String?> releaseDate = const Value.absent(),
          Value<String?> genres = const Value.absent(),
          Value<String?> streamingServices = const Value.absent(),
          bool? isAnime,
          Value<int?> totalSeasons = const Value.absent(),
          Value<int?> totalEpisodes = const Value.absent(),
          DateTime? updatedAt}) =>
      CachedTitle(
        id: id ?? this.id,
        title: title ?? this.title,
        mediaType: mediaType ?? this.mediaType,
        posterPath: posterPath.present ? posterPath.value : this.posterPath,
        backdropPath:
            backdropPath.present ? backdropPath.value : this.backdropPath,
        overview: overview.present ? overview.value : this.overview,
        releaseDate: releaseDate.present ? releaseDate.value : this.releaseDate,
        genres: genres.present ? genres.value : this.genres,
        streamingServices: streamingServices.present
            ? streamingServices.value
            : this.streamingServices,
        isAnime: isAnime ?? this.isAnime,
        totalSeasons:
            totalSeasons.present ? totalSeasons.value : this.totalSeasons,
        totalEpisodes:
            totalEpisodes.present ? totalEpisodes.value : this.totalEpisodes,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  CachedTitle copyWithCompanion(CachedTitlesCompanion data) {
    return CachedTitle(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      posterPath:
          data.posterPath.present ? data.posterPath.value : this.posterPath,
      backdropPath: data.backdropPath.present
          ? data.backdropPath.value
          : this.backdropPath,
      overview: data.overview.present ? data.overview.value : this.overview,
      releaseDate:
          data.releaseDate.present ? data.releaseDate.value : this.releaseDate,
      genres: data.genres.present ? data.genres.value : this.genres,
      streamingServices: data.streamingServices.present
          ? data.streamingServices.value
          : this.streamingServices,
      isAnime: data.isAnime.present ? data.isAnime.value : this.isAnime,
      totalSeasons: data.totalSeasons.present
          ? data.totalSeasons.value
          : this.totalSeasons,
      totalEpisodes: data.totalEpisodes.present
          ? data.totalEpisodes.value
          : this.totalEpisodes,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedTitle(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('mediaType: $mediaType, ')
          ..write('posterPath: $posterPath, ')
          ..write('backdropPath: $backdropPath, ')
          ..write('overview: $overview, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('genres: $genres, ')
          ..write('streamingServices: $streamingServices, ')
          ..write('isAnime: $isAnime, ')
          ..write('totalSeasons: $totalSeasons, ')
          ..write('totalEpisodes: $totalEpisodes, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      title,
      mediaType,
      posterPath,
      backdropPath,
      overview,
      releaseDate,
      genres,
      streamingServices,
      isAnime,
      totalSeasons,
      totalEpisodes,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedTitle &&
          other.id == this.id &&
          other.title == this.title &&
          other.mediaType == this.mediaType &&
          other.posterPath == this.posterPath &&
          other.backdropPath == this.backdropPath &&
          other.overview == this.overview &&
          other.releaseDate == this.releaseDate &&
          other.genres == this.genres &&
          other.streamingServices == this.streamingServices &&
          other.isAnime == this.isAnime &&
          other.totalSeasons == this.totalSeasons &&
          other.totalEpisodes == this.totalEpisodes &&
          other.updatedAt == this.updatedAt);
}

class CachedTitlesCompanion extends UpdateCompanion<CachedTitle> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> mediaType;
  final Value<String?> posterPath;
  final Value<String?> backdropPath;
  final Value<String?> overview;
  final Value<String?> releaseDate;
  final Value<String?> genres;
  final Value<String?> streamingServices;
  final Value<bool> isAnime;
  final Value<int?> totalSeasons;
  final Value<int?> totalEpisodes;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CachedTitlesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.posterPath = const Value.absent(),
    this.backdropPath = const Value.absent(),
    this.overview = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.genres = const Value.absent(),
    this.streamingServices = const Value.absent(),
    this.isAnime = const Value.absent(),
    this.totalSeasons = const Value.absent(),
    this.totalEpisodes = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedTitlesCompanion.insert({
    required int id,
    required String title,
    required String mediaType,
    this.posterPath = const Value.absent(),
    this.backdropPath = const Value.absent(),
    this.overview = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.genres = const Value.absent(),
    this.streamingServices = const Value.absent(),
    this.isAnime = const Value.absent(),
    this.totalSeasons = const Value.absent(),
    this.totalEpisodes = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        mediaType = Value(mediaType);
  static Insertable<CachedTitle> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? mediaType,
    Expression<String>? posterPath,
    Expression<String>? backdropPath,
    Expression<String>? overview,
    Expression<String>? releaseDate,
    Expression<String>? genres,
    Expression<String>? streamingServices,
    Expression<bool>? isAnime,
    Expression<int>? totalSeasons,
    Expression<int>? totalEpisodes,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (mediaType != null) 'media_type': mediaType,
      if (posterPath != null) 'poster_path': posterPath,
      if (backdropPath != null) 'backdrop_path': backdropPath,
      if (overview != null) 'overview': overview,
      if (releaseDate != null) 'release_date': releaseDate,
      if (genres != null) 'genres': genres,
      if (streamingServices != null) 'streaming_services': streamingServices,
      if (isAnime != null) 'is_anime': isAnime,
      if (totalSeasons != null) 'total_seasons': totalSeasons,
      if (totalEpisodes != null) 'total_episodes': totalEpisodes,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedTitlesCompanion copyWith(
      {Value<int>? id,
      Value<String>? title,
      Value<String>? mediaType,
      Value<String?>? posterPath,
      Value<String?>? backdropPath,
      Value<String?>? overview,
      Value<String?>? releaseDate,
      Value<String?>? genres,
      Value<String?>? streamingServices,
      Value<bool>? isAnime,
      Value<int?>? totalSeasons,
      Value<int?>? totalEpisodes,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return CachedTitlesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      mediaType: mediaType ?? this.mediaType,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      overview: overview ?? this.overview,
      releaseDate: releaseDate ?? this.releaseDate,
      genres: genres ?? this.genres,
      streamingServices: streamingServices ?? this.streamingServices,
      isAnime: isAnime ?? this.isAnime,
      totalSeasons: totalSeasons ?? this.totalSeasons,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (posterPath.present) {
      map['poster_path'] = Variable<String>(posterPath.value);
    }
    if (backdropPath.present) {
      map['backdrop_path'] = Variable<String>(backdropPath.value);
    }
    if (overview.present) {
      map['overview'] = Variable<String>(overview.value);
    }
    if (releaseDate.present) {
      map['release_date'] = Variable<String>(releaseDate.value);
    }
    if (genres.present) {
      map['genres'] = Variable<String>(genres.value);
    }
    if (streamingServices.present) {
      map['streaming_services'] = Variable<String>(streamingServices.value);
    }
    if (isAnime.present) {
      map['is_anime'] = Variable<bool>(isAnime.value);
    }
    if (totalSeasons.present) {
      map['total_seasons'] = Variable<int>(totalSeasons.value);
    }
    if (totalEpisodes.present) {
      map['total_episodes'] = Variable<int>(totalEpisodes.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedTitlesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('mediaType: $mediaType, ')
          ..write('posterPath: $posterPath, ')
          ..write('backdropPath: $backdropPath, ')
          ..write('overview: $overview, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('genres: $genres, ')
          ..write('streamingServices: $streamingServices, ')
          ..write('isAnime: $isAnime, ')
          ..write('totalSeasons: $totalSeasons, ')
          ..write('totalEpisodes: $totalEpisodes, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalRankingsTable extends LocalRankings
    with TableInfo<$LocalRankingsTable, LocalRanking> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalRankingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _showIdMeta = const VerificationMeta('showId');
  @override
  late final GeneratedColumn<int> showId = GeneratedColumn<int>(
      'show_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _mediaTypeMeta =
      const VerificationMeta('mediaType');
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
      'media_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _posterPathMeta =
      const VerificationMeta('posterPath');
  @override
  late final GeneratedColumn<String> posterPath = GeneratedColumn<String>(
      'poster_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _rankPositionMeta =
      const VerificationMeta('rankPosition');
  @override
  late final GeneratedColumn<int> rankPosition = GeneratedColumn<int>(
      'rank_position', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _calculatedScoreMeta =
      const VerificationMeta('calculatedScore');
  @override
  late final GeneratedColumn<double> calculatedScore = GeneratedColumn<double>(
      'calculated_score', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _bracketMeta =
      const VerificationMeta('bracket');
  @override
  late final GeneratedColumn<String> bracket = GeneratedColumn<String>(
      'bracket', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _favoriteCharacterMeta =
      const VerificationMeta('favoriteCharacter');
  @override
  late final GeneratedColumn<String> favoriteCharacter =
      GeneratedColumn<String>('favorite_character', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('SYNCED'));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        showId,
        mediaType,
        title,
        posterPath,
        rankPosition,
        calculatedScore,
        bracket,
        favoriteCharacter,
        syncStatus,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_rankings';
  @override
  VerificationContext validateIntegrity(Insertable<LocalRanking> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('show_id')) {
      context.handle(_showIdMeta,
          showId.isAcceptableOrUnknown(data['show_id']!, _showIdMeta));
    } else if (isInserting) {
      context.missing(_showIdMeta);
    }
    if (data.containsKey('media_type')) {
      context.handle(_mediaTypeMeta,
          mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta));
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('poster_path')) {
      context.handle(
          _posterPathMeta,
          posterPath.isAcceptableOrUnknown(
              data['poster_path']!, _posterPathMeta));
    }
    if (data.containsKey('rank_position')) {
      context.handle(
          _rankPositionMeta,
          rankPosition.isAcceptableOrUnknown(
              data['rank_position']!, _rankPositionMeta));
    } else if (isInserting) {
      context.missing(_rankPositionMeta);
    }
    if (data.containsKey('calculated_score')) {
      context.handle(
          _calculatedScoreMeta,
          calculatedScore.isAcceptableOrUnknown(
              data['calculated_score']!, _calculatedScoreMeta));
    } else if (isInserting) {
      context.missing(_calculatedScoreMeta);
    }
    if (data.containsKey('bracket')) {
      context.handle(_bracketMeta,
          bracket.isAcceptableOrUnknown(data['bracket']!, _bracketMeta));
    }
    if (data.containsKey('favorite_character')) {
      context.handle(
          _favoriteCharacterMeta,
          favoriteCharacter.isAcceptableOrUnknown(
              data['favorite_character']!, _favoriteCharacterMeta));
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {showId, mediaType};
  @override
  LocalRanking map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalRanking(
      showId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}show_id'])!,
      mediaType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_type'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      posterPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}poster_path']),
      rankPosition: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rank_position'])!,
      calculatedScore: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}calculated_score'])!,
      bracket: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bracket']),
      favoriteCharacter: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}favorite_character']),
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LocalRankingsTable createAlias(String alias) {
    return $LocalRankingsTable(attachedDatabase, alias);
  }
}

class LocalRanking extends DataClass implements Insertable<LocalRanking> {
  final int showId;
  final String mediaType;
  final String title;
  final String? posterPath;
  final int rankPosition;
  final double calculatedScore;
  final String? bracket;
  final String? favoriteCharacter;
  final String syncStatus;
  final DateTime updatedAt;
  const LocalRanking(
      {required this.showId,
      required this.mediaType,
      required this.title,
      this.posterPath,
      required this.rankPosition,
      required this.calculatedScore,
      this.bracket,
      this.favoriteCharacter,
      required this.syncStatus,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['show_id'] = Variable<int>(showId);
    map['media_type'] = Variable<String>(mediaType);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || posterPath != null) {
      map['poster_path'] = Variable<String>(posterPath);
    }
    map['rank_position'] = Variable<int>(rankPosition);
    map['calculated_score'] = Variable<double>(calculatedScore);
    if (!nullToAbsent || bracket != null) {
      map['bracket'] = Variable<String>(bracket);
    }
    if (!nullToAbsent || favoriteCharacter != null) {
      map['favorite_character'] = Variable<String>(favoriteCharacter);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalRankingsCompanion toCompanion(bool nullToAbsent) {
    return LocalRankingsCompanion(
      showId: Value(showId),
      mediaType: Value(mediaType),
      title: Value(title),
      posterPath: posterPath == null && nullToAbsent
          ? const Value.absent()
          : Value(posterPath),
      rankPosition: Value(rankPosition),
      calculatedScore: Value(calculatedScore),
      bracket: bracket == null && nullToAbsent
          ? const Value.absent()
          : Value(bracket),
      favoriteCharacter: favoriteCharacter == null && nullToAbsent
          ? const Value.absent()
          : Value(favoriteCharacter),
      syncStatus: Value(syncStatus),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalRanking.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalRanking(
      showId: serializer.fromJson<int>(json['showId']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      title: serializer.fromJson<String>(json['title']),
      posterPath: serializer.fromJson<String?>(json['posterPath']),
      rankPosition: serializer.fromJson<int>(json['rankPosition']),
      calculatedScore: serializer.fromJson<double>(json['calculatedScore']),
      bracket: serializer.fromJson<String?>(json['bracket']),
      favoriteCharacter:
          serializer.fromJson<String?>(json['favoriteCharacter']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'showId': serializer.toJson<int>(showId),
      'mediaType': serializer.toJson<String>(mediaType),
      'title': serializer.toJson<String>(title),
      'posterPath': serializer.toJson<String?>(posterPath),
      'rankPosition': serializer.toJson<int>(rankPosition),
      'calculatedScore': serializer.toJson<double>(calculatedScore),
      'bracket': serializer.toJson<String?>(bracket),
      'favoriteCharacter': serializer.toJson<String?>(favoriteCharacter),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalRanking copyWith(
          {int? showId,
          String? mediaType,
          String? title,
          Value<String?> posterPath = const Value.absent(),
          int? rankPosition,
          double? calculatedScore,
          Value<String?> bracket = const Value.absent(),
          Value<String?> favoriteCharacter = const Value.absent(),
          String? syncStatus,
          DateTime? updatedAt}) =>
      LocalRanking(
        showId: showId ?? this.showId,
        mediaType: mediaType ?? this.mediaType,
        title: title ?? this.title,
        posterPath: posterPath.present ? posterPath.value : this.posterPath,
        rankPosition: rankPosition ?? this.rankPosition,
        calculatedScore: calculatedScore ?? this.calculatedScore,
        bracket: bracket.present ? bracket.value : this.bracket,
        favoriteCharacter: favoriteCharacter.present
            ? favoriteCharacter.value
            : this.favoriteCharacter,
        syncStatus: syncStatus ?? this.syncStatus,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LocalRanking copyWithCompanion(LocalRankingsCompanion data) {
    return LocalRanking(
      showId: data.showId.present ? data.showId.value : this.showId,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      title: data.title.present ? data.title.value : this.title,
      posterPath:
          data.posterPath.present ? data.posterPath.value : this.posterPath,
      rankPosition: data.rankPosition.present
          ? data.rankPosition.value
          : this.rankPosition,
      calculatedScore: data.calculatedScore.present
          ? data.calculatedScore.value
          : this.calculatedScore,
      bracket: data.bracket.present ? data.bracket.value : this.bracket,
      favoriteCharacter: data.favoriteCharacter.present
          ? data.favoriteCharacter.value
          : this.favoriteCharacter,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalRanking(')
          ..write('showId: $showId, ')
          ..write('mediaType: $mediaType, ')
          ..write('title: $title, ')
          ..write('posterPath: $posterPath, ')
          ..write('rankPosition: $rankPosition, ')
          ..write('calculatedScore: $calculatedScore, ')
          ..write('bracket: $bracket, ')
          ..write('favoriteCharacter: $favoriteCharacter, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      showId,
      mediaType,
      title,
      posterPath,
      rankPosition,
      calculatedScore,
      bracket,
      favoriteCharacter,
      syncStatus,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalRanking &&
          other.showId == this.showId &&
          other.mediaType == this.mediaType &&
          other.title == this.title &&
          other.posterPath == this.posterPath &&
          other.rankPosition == this.rankPosition &&
          other.calculatedScore == this.calculatedScore &&
          other.bracket == this.bracket &&
          other.favoriteCharacter == this.favoriteCharacter &&
          other.syncStatus == this.syncStatus &&
          other.updatedAt == this.updatedAt);
}

class LocalRankingsCompanion extends UpdateCompanion<LocalRanking> {
  final Value<int> showId;
  final Value<String> mediaType;
  final Value<String> title;
  final Value<String?> posterPath;
  final Value<int> rankPosition;
  final Value<double> calculatedScore;
  final Value<String?> bracket;
  final Value<String?> favoriteCharacter;
  final Value<String> syncStatus;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalRankingsCompanion({
    this.showId = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.title = const Value.absent(),
    this.posterPath = const Value.absent(),
    this.rankPosition = const Value.absent(),
    this.calculatedScore = const Value.absent(),
    this.bracket = const Value.absent(),
    this.favoriteCharacter = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalRankingsCompanion.insert({
    required int showId,
    required String mediaType,
    required String title,
    this.posterPath = const Value.absent(),
    required int rankPosition,
    required double calculatedScore,
    this.bracket = const Value.absent(),
    this.favoriteCharacter = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : showId = Value(showId),
        mediaType = Value(mediaType),
        title = Value(title),
        rankPosition = Value(rankPosition),
        calculatedScore = Value(calculatedScore);
  static Insertable<LocalRanking> custom({
    Expression<int>? showId,
    Expression<String>? mediaType,
    Expression<String>? title,
    Expression<String>? posterPath,
    Expression<int>? rankPosition,
    Expression<double>? calculatedScore,
    Expression<String>? bracket,
    Expression<String>? favoriteCharacter,
    Expression<String>? syncStatus,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (showId != null) 'show_id': showId,
      if (mediaType != null) 'media_type': mediaType,
      if (title != null) 'title': title,
      if (posterPath != null) 'poster_path': posterPath,
      if (rankPosition != null) 'rank_position': rankPosition,
      if (calculatedScore != null) 'calculated_score': calculatedScore,
      if (bracket != null) 'bracket': bracket,
      if (favoriteCharacter != null) 'favorite_character': favoriteCharacter,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalRankingsCompanion copyWith(
      {Value<int>? showId,
      Value<String>? mediaType,
      Value<String>? title,
      Value<String?>? posterPath,
      Value<int>? rankPosition,
      Value<double>? calculatedScore,
      Value<String?>? bracket,
      Value<String?>? favoriteCharacter,
      Value<String>? syncStatus,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return LocalRankingsCompanion(
      showId: showId ?? this.showId,
      mediaType: mediaType ?? this.mediaType,
      title: title ?? this.title,
      posterPath: posterPath ?? this.posterPath,
      rankPosition: rankPosition ?? this.rankPosition,
      calculatedScore: calculatedScore ?? this.calculatedScore,
      bracket: bracket ?? this.bracket,
      favoriteCharacter: favoriteCharacter ?? this.favoriteCharacter,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (showId.present) {
      map['show_id'] = Variable<int>(showId.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (posterPath.present) {
      map['poster_path'] = Variable<String>(posterPath.value);
    }
    if (rankPosition.present) {
      map['rank_position'] = Variable<int>(rankPosition.value);
    }
    if (calculatedScore.present) {
      map['calculated_score'] = Variable<double>(calculatedScore.value);
    }
    if (bracket.present) {
      map['bracket'] = Variable<String>(bracket.value);
    }
    if (favoriteCharacter.present) {
      map['favorite_character'] = Variable<String>(favoriteCharacter.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalRankingsCompanion(')
          ..write('showId: $showId, ')
          ..write('mediaType: $mediaType, ')
          ..write('title: $title, ')
          ..write('posterPath: $posterPath, ')
          ..write('rankPosition: $rankPosition, ')
          ..write('calculatedScore: $calculatedScore, ')
          ..write('bracket: $bracket, ')
          ..write('favoriteCharacter: $favoriteCharacter, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingMutationsTable extends PendingMutations
    with TableInfo<$PendingMutationsTable, PendingMutation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingMutationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
      'seq', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [seq, id, kind, payload, createdAt, attempts, lastError];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_mutations';
  @override
  VerificationContext validateIntegrity(Insertable<PendingMutation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
          _seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  PendingMutation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingMutation(
      seq: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}seq'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
    );
  }

  @override
  $PendingMutationsTable createAlias(String alias) {
    return $PendingMutationsTable(attachedDatabase, alias);
  }
}

class PendingMutation extends DataClass implements Insertable<PendingMutation> {
  final int seq;
  final String id;
  final String kind;
  final String payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
  const PendingMutation(
      {required this.seq,
      required this.id,
      required this.kind,
      required this.payload,
      required this.createdAt,
      required this.attempts,
      this.lastError});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  PendingMutationsCompanion toCompanion(bool nullToAbsent) {
    return PendingMutationsCompanion(
      seq: Value(seq),
      id: Value(id),
      kind: Value(kind),
      payload: Value(payload),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory PendingMutation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingMutation(
      seq: serializer.fromJson<int>(json['seq']),
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  PendingMutation copyWith(
          {int? seq,
          String? id,
          String? kind,
          String? payload,
          DateTime? createdAt,
          int? attempts,
          Value<String?> lastError = const Value.absent()}) =>
      PendingMutation(
        seq: seq ?? this.seq,
        id: id ?? this.id,
        kind: kind ?? this.kind,
        payload: payload ?? this.payload,
        createdAt: createdAt ?? this.createdAt,
        attempts: attempts ?? this.attempts,
        lastError: lastError.present ? lastError.value : this.lastError,
      );
  PendingMutation copyWithCompanion(PendingMutationsCompanion data) {
    return PendingMutation(
      seq: data.seq.present ? data.seq.value : this.seq,
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingMutation(')
          ..write('seq: $seq, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(seq, id, kind, payload, createdAt, attempts, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingMutation &&
          other.seq == this.seq &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError);
}

class PendingMutationsCompanion extends UpdateCompanion<PendingMutation> {
  final Value<int> seq;
  final Value<String> id;
  final Value<String> kind;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  const PendingMutationsCompanion({
    this.seq = const Value.absent(),
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  PendingMutationsCompanion.insert({
    this.seq = const Value.absent(),
    required String id,
    required String kind,
    required String payload,
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  })  : id = Value(id),
        kind = Value(kind),
        payload = Value(payload);
  static Insertable<PendingMutation> custom({
    Expression<int>? seq,
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
    });
  }

  PendingMutationsCompanion copyWith(
      {Value<int>? seq,
      Value<String>? id,
      Value<String>? kind,
      Value<String>? payload,
      Value<DateTime>? createdAt,
      Value<int>? attempts,
      Value<String?>? lastError}) {
    return PendingMutationsCompanion(
      seq: seq ?? this.seq,
      id: id ?? this.id,
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingMutationsCompanion(')
          ..write('seq: $seq, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $WatchlistCacheTable extends WatchlistCache
    with TableInfo<$WatchlistCacheTable, WatchlistCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchlistCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _titleIdMeta =
      const VerificationMeta('titleId');
  @override
  late final GeneratedColumn<int> titleId = GeneratedColumn<int>(
      'title_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _mediaTypeMeta =
      const VerificationMeta('mediaType');
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
      'media_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _posterPathMeta =
      const VerificationMeta('posterPath');
  @override
  late final GeneratedColumn<String> posterPath = GeneratedColumn<String>(
      'poster_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _savedAtMeta =
      const VerificationMeta('savedAt');
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
      'saved_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('SYNCED'));
  @override
  List<GeneratedColumn> get $columns =>
      [titleId, mediaType, title, posterPath, savedAt, syncStatus];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watchlist_cache';
  @override
  VerificationContext validateIntegrity(Insertable<WatchlistCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('title_id')) {
      context.handle(_titleIdMeta,
          titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta));
    } else if (isInserting) {
      context.missing(_titleIdMeta);
    }
    if (data.containsKey('media_type')) {
      context.handle(_mediaTypeMeta,
          mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta));
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('poster_path')) {
      context.handle(
          _posterPathMeta,
          posterPath.isAcceptableOrUnknown(
              data['poster_path']!, _posterPathMeta));
    }
    if (data.containsKey('saved_at')) {
      context.handle(_savedAtMeta,
          savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta));
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {titleId, mediaType};
  @override
  WatchlistCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchlistCacheData(
      titleId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}title_id'])!,
      mediaType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_type'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      posterPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}poster_path']),
      savedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}saved_at'])!,
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
    );
  }

  @override
  $WatchlistCacheTable createAlias(String alias) {
    return $WatchlistCacheTable(attachedDatabase, alias);
  }
}

class WatchlistCacheData extends DataClass
    implements Insertable<WatchlistCacheData> {
  final int titleId;
  final String mediaType;
  final String title;
  final String? posterPath;
  final DateTime savedAt;
  final String syncStatus;
  const WatchlistCacheData(
      {required this.titleId,
      required this.mediaType,
      required this.title,
      this.posterPath,
      required this.savedAt,
      required this.syncStatus});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['title_id'] = Variable<int>(titleId);
    map['media_type'] = Variable<String>(mediaType);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || posterPath != null) {
      map['poster_path'] = Variable<String>(posterPath);
    }
    map['saved_at'] = Variable<DateTime>(savedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  WatchlistCacheCompanion toCompanion(bool nullToAbsent) {
    return WatchlistCacheCompanion(
      titleId: Value(titleId),
      mediaType: Value(mediaType),
      title: Value(title),
      posterPath: posterPath == null && nullToAbsent
          ? const Value.absent()
          : Value(posterPath),
      savedAt: Value(savedAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory WatchlistCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchlistCacheData(
      titleId: serializer.fromJson<int>(json['titleId']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      title: serializer.fromJson<String>(json['title']),
      posterPath: serializer.fromJson<String?>(json['posterPath']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'titleId': serializer.toJson<int>(titleId),
      'mediaType': serializer.toJson<String>(mediaType),
      'title': serializer.toJson<String>(title),
      'posterPath': serializer.toJson<String?>(posterPath),
      'savedAt': serializer.toJson<DateTime>(savedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  WatchlistCacheData copyWith(
          {int? titleId,
          String? mediaType,
          String? title,
          Value<String?> posterPath = const Value.absent(),
          DateTime? savedAt,
          String? syncStatus}) =>
      WatchlistCacheData(
        titleId: titleId ?? this.titleId,
        mediaType: mediaType ?? this.mediaType,
        title: title ?? this.title,
        posterPath: posterPath.present ? posterPath.value : this.posterPath,
        savedAt: savedAt ?? this.savedAt,
        syncStatus: syncStatus ?? this.syncStatus,
      );
  WatchlistCacheData copyWithCompanion(WatchlistCacheCompanion data) {
    return WatchlistCacheData(
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      title: data.title.present ? data.title.value : this.title,
      posterPath:
          data.posterPath.present ? data.posterPath.value : this.posterPath,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchlistCacheData(')
          ..write('titleId: $titleId, ')
          ..write('mediaType: $mediaType, ')
          ..write('title: $title, ')
          ..write('posterPath: $posterPath, ')
          ..write('savedAt: $savedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(titleId, mediaType, title, posterPath, savedAt, syncStatus);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchlistCacheData &&
          other.titleId == this.titleId &&
          other.mediaType == this.mediaType &&
          other.title == this.title &&
          other.posterPath == this.posterPath &&
          other.savedAt == this.savedAt &&
          other.syncStatus == this.syncStatus);
}

class WatchlistCacheCompanion extends UpdateCompanion<WatchlistCacheData> {
  final Value<int> titleId;
  final Value<String> mediaType;
  final Value<String> title;
  final Value<String?> posterPath;
  final Value<DateTime> savedAt;
  final Value<String> syncStatus;
  final Value<int> rowid;
  const WatchlistCacheCompanion({
    this.titleId = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.title = const Value.absent(),
    this.posterPath = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchlistCacheCompanion.insert({
    required int titleId,
    required String mediaType,
    required String title,
    this.posterPath = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : titleId = Value(titleId),
        mediaType = Value(mediaType),
        title = Value(title);
  static Insertable<WatchlistCacheData> custom({
    Expression<int>? titleId,
    Expression<String>? mediaType,
    Expression<String>? title,
    Expression<String>? posterPath,
    Expression<DateTime>? savedAt,
    Expression<String>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (titleId != null) 'title_id': titleId,
      if (mediaType != null) 'media_type': mediaType,
      if (title != null) 'title': title,
      if (posterPath != null) 'poster_path': posterPath,
      if (savedAt != null) 'saved_at': savedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchlistCacheCompanion copyWith(
      {Value<int>? titleId,
      Value<String>? mediaType,
      Value<String>? title,
      Value<String?>? posterPath,
      Value<DateTime>? savedAt,
      Value<String>? syncStatus,
      Value<int>? rowid}) {
    return WatchlistCacheCompanion(
      titleId: titleId ?? this.titleId,
      mediaType: mediaType ?? this.mediaType,
      title: title ?? this.title,
      posterPath: posterPath ?? this.posterPath,
      savedAt: savedAt ?? this.savedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (titleId.present) {
      map['title_id'] = Variable<int>(titleId.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (posterPath.present) {
      map['poster_path'] = Variable<String>(posterPath.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchlistCacheCompanion(')
          ..write('titleId: $titleId, ')
          ..write('mediaType: $mediaType, ')
          ..write('title: $title, ')
          ..write('posterPath: $posterPath, ')
          ..write('savedAt: $savedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GamificationCacheTable extends GamificationCache
    with TableInfo<$GamificationCacheTable, GamificationCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GamificationCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _savedAtMeta =
      const VerificationMeta('savedAt');
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
      'saved_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [key, json, savedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gamification_cache';
  @override
  VerificationContext validateIntegrity(
      Insertable<GamificationCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('saved_at')) {
      context.handle(_savedAtMeta,
          savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  GamificationCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GamificationCacheData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
      savedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}saved_at'])!,
    );
  }

  @override
  $GamificationCacheTable createAlias(String alias) {
    return $GamificationCacheTable(attachedDatabase, alias);
  }
}

class GamificationCacheData extends DataClass
    implements Insertable<GamificationCacheData> {
  final String key;
  final String json;
  final DateTime savedAt;
  const GamificationCacheData(
      {required this.key, required this.json, required this.savedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['json'] = Variable<String>(json);
    map['saved_at'] = Variable<DateTime>(savedAt);
    return map;
  }

  GamificationCacheCompanion toCompanion(bool nullToAbsent) {
    return GamificationCacheCompanion(
      key: Value(key),
      json: Value(json),
      savedAt: Value(savedAt),
    );
  }

  factory GamificationCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GamificationCacheData(
      key: serializer.fromJson<String>(json['key']),
      json: serializer.fromJson<String>(json['json']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'json': serializer.toJson<String>(json),
      'savedAt': serializer.toJson<DateTime>(savedAt),
    };
  }

  GamificationCacheData copyWith(
          {String? key, String? json, DateTime? savedAt}) =>
      GamificationCacheData(
        key: key ?? this.key,
        json: json ?? this.json,
        savedAt: savedAt ?? this.savedAt,
      );
  GamificationCacheData copyWithCompanion(GamificationCacheCompanion data) {
    return GamificationCacheData(
      key: data.key.present ? data.key.value : this.key,
      json: data.json.present ? data.json.value : this.json,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GamificationCacheData(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, json, savedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GamificationCacheData &&
          other.key == this.key &&
          other.json == this.json &&
          other.savedAt == this.savedAt);
}

class GamificationCacheCompanion
    extends UpdateCompanion<GamificationCacheData> {
  final Value<String> key;
  final Value<String> json;
  final Value<DateTime> savedAt;
  final Value<int> rowid;
  const GamificationCacheCompanion({
    this.key = const Value.absent(),
    this.json = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GamificationCacheCompanion.insert({
    required String key,
    required String json,
    this.savedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        json = Value(json);
  static Insertable<GamificationCacheData> custom({
    Expression<String>? key,
    Expression<String>? json,
    Expression<DateTime>? savedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (json != null) 'json': json,
      if (savedAt != null) 'saved_at': savedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GamificationCacheCompanion copyWith(
      {Value<String>? key,
      Value<String>? json,
      Value<DateTime>? savedAt,
      Value<int>? rowid}) {
    return GamificationCacheCompanion(
      key: key ?? this.key,
      json: json ?? this.json,
      savedAt: savedAt ?? this.savedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GamificationCacheCompanion(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('savedAt: $savedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExploreCacheTable extends ExploreCache
    with TableInfo<$ExploreCacheTable, ExploreCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExploreCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaTypeMeta =
      const VerificationMeta('mediaType');
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
      'media_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _savedAtMeta =
      const VerificationMeta('savedAt');
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
      'saved_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [mediaType, json, savedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'explore_cache';
  @override
  VerificationContext validateIntegrity(Insertable<ExploreCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_type')) {
      context.handle(_mediaTypeMeta,
          mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta));
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('saved_at')) {
      context.handle(_savedAtMeta,
          savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaType};
  @override
  ExploreCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExploreCacheData(
      mediaType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_type'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
      savedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}saved_at'])!,
    );
  }

  @override
  $ExploreCacheTable createAlias(String alias) {
    return $ExploreCacheTable(attachedDatabase, alias);
  }
}

class ExploreCacheData extends DataClass
    implements Insertable<ExploreCacheData> {
  final String mediaType;
  final String json;
  final DateTime savedAt;
  const ExploreCacheData(
      {required this.mediaType, required this.json, required this.savedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_type'] = Variable<String>(mediaType);
    map['json'] = Variable<String>(json);
    map['saved_at'] = Variable<DateTime>(savedAt);
    return map;
  }

  ExploreCacheCompanion toCompanion(bool nullToAbsent) {
    return ExploreCacheCompanion(
      mediaType: Value(mediaType),
      json: Value(json),
      savedAt: Value(savedAt),
    );
  }

  factory ExploreCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExploreCacheData(
      mediaType: serializer.fromJson<String>(json['mediaType']),
      json: serializer.fromJson<String>(json['json']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaType': serializer.toJson<String>(mediaType),
      'json': serializer.toJson<String>(json),
      'savedAt': serializer.toJson<DateTime>(savedAt),
    };
  }

  ExploreCacheData copyWith(
          {String? mediaType, String? json, DateTime? savedAt}) =>
      ExploreCacheData(
        mediaType: mediaType ?? this.mediaType,
        json: json ?? this.json,
        savedAt: savedAt ?? this.savedAt,
      );
  ExploreCacheData copyWithCompanion(ExploreCacheCompanion data) {
    return ExploreCacheData(
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      json: data.json.present ? data.json.value : this.json,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExploreCacheData(')
          ..write('mediaType: $mediaType, ')
          ..write('json: $json, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mediaType, json, savedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExploreCacheData &&
          other.mediaType == this.mediaType &&
          other.json == this.json &&
          other.savedAt == this.savedAt);
}

class ExploreCacheCompanion extends UpdateCompanion<ExploreCacheData> {
  final Value<String> mediaType;
  final Value<String> json;
  final Value<DateTime> savedAt;
  final Value<int> rowid;
  const ExploreCacheCompanion({
    this.mediaType = const Value.absent(),
    this.json = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExploreCacheCompanion.insert({
    required String mediaType,
    required String json,
    this.savedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : mediaType = Value(mediaType),
        json = Value(json);
  static Insertable<ExploreCacheData> custom({
    Expression<String>? mediaType,
    Expression<String>? json,
    Expression<DateTime>? savedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mediaType != null) 'media_type': mediaType,
      if (json != null) 'json': json,
      if (savedAt != null) 'saved_at': savedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExploreCacheCompanion copyWith(
      {Value<String>? mediaType,
      Value<String>? json,
      Value<DateTime>? savedAt,
      Value<int>? rowid}) {
    return ExploreCacheCompanion(
      mediaType: mediaType ?? this.mediaType,
      json: json ?? this.json,
      savedAt: savedAt ?? this.savedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExploreCacheCompanion(')
          ..write('mediaType: $mediaType, ')
          ..write('json: $json, ')
          ..write('savedAt: $savedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrackingCacheTable extends TrackingCache
    with TableInfo<$TrackingCacheTable, TrackingCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackingCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _titleIdMeta =
      const VerificationMeta('titleId');
  @override
  late final GeneratedColumn<int> titleId = GeneratedColumn<int>(
      'title_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _mediaTypeMeta =
      const VerificationMeta('mediaType');
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
      'media_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _posterPathMeta =
      const VerificationMeta('posterPath');
  @override
  late final GeneratedColumn<String> posterPath = GeneratedColumn<String>(
      'poster_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _backdropPathMeta =
      const VerificationMeta('backdropPath');
  @override
  late final GeneratedColumn<String> backdropPath = GeneratedColumn<String>(
      'backdrop_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _titleStatusMeta =
      const VerificationMeta('titleStatus');
  @override
  late final GeneratedColumn<String> titleStatus = GeneratedColumn<String>(
      'title_status', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _runtimeMinutesMeta =
      const VerificationMeta('runtimeMinutes');
  @override
  late final GeneratedColumn<int> runtimeMinutes = GeneratedColumn<int>(
      'runtime_minutes', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _lastSeasonMeta =
      const VerificationMeta('lastSeason');
  @override
  late final GeneratedColumn<int> lastSeason = GeneratedColumn<int>(
      'last_season', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _lastEpisodeMeta =
      const VerificationMeta('lastEpisode');
  @override
  late final GeneratedColumn<int> lastEpisode = GeneratedColumn<int>(
      'last_episode', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
      'state', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('WATCHING'));
  static const VerificationMeta _isRewatchMeta =
      const VerificationMeta('isRewatch');
  @override
  late final GeneratedColumn<bool> isRewatch = GeneratedColumn<bool>(
      'is_rewatch', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_rewatch" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _newEpisodesSinceMeta =
      const VerificationMeta('newEpisodesSince');
  @override
  late final GeneratedColumn<DateTime> newEpisodesSince =
      GeneratedColumn<DateTime>('new_episodes_since', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
      'started_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _lastProgressAtMeta =
      const VerificationMeta('lastProgressAt');
  @override
  late final GeneratedColumn<DateTime> lastProgressAt =
      GeneratedColumn<DateTime>('last_progress_at', aliasedName, false,
          type: DriftSqlType.dateTime,
          requiredDuringInsert: false,
          defaultValue: currentDateAndTime);
  static const VerificationMeta _finishedAtMeta =
      const VerificationMeta('finishedAt');
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
      'finished_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _seasonsMeta =
      const VerificationMeta('seasons');
  @override
  late final GeneratedColumn<String> seasons = GeneratedColumn<String>(
      'seasons', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _watchedMeta =
      const VerificationMeta('watched');
  @override
  late final GeneratedColumn<int> watched = GeneratedColumn<int>(
      'watched', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _airedTotalMeta =
      const VerificationMeta('airedTotal');
  @override
  late final GeneratedColumn<int> airedTotal = GeneratedColumn<int>(
      'aired_total', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nextEpisodeMeta =
      const VerificationMeta('nextEpisode');
  @override
  late final GeneratedColumn<String> nextEpisode = GeneratedColumn<String>(
      'next_episode', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastAiredMeta =
      const VerificationMeta('lastAired');
  @override
  late final GeneratedColumn<String> lastAired = GeneratedColumn<String>(
      'last_aired', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _rankedMeta = const VerificationMeta('ranked');
  @override
  late final GeneratedColumn<bool> ranked = GeneratedColumn<bool>(
      'ranked', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("ranked" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _rankPositionMeta =
      const VerificationMeta('rankPosition');
  @override
  late final GeneratedColumn<int> rankPosition = GeneratedColumn<int>(
      'rank_position', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
      'score', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('SYNCED'));
  @override
  List<GeneratedColumn> get $columns => [
        titleId,
        mediaType,
        title,
        posterPath,
        backdropPath,
        titleStatus,
        runtimeMinutes,
        lastSeason,
        lastEpisode,
        state,
        isRewatch,
        newEpisodesSince,
        startedAt,
        lastProgressAt,
        finishedAt,
        seasons,
        watched,
        airedTotal,
        nextEpisode,
        lastAired,
        ranked,
        rankPosition,
        score,
        syncStatus
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracking_cache';
  @override
  VerificationContext validateIntegrity(Insertable<TrackingCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('title_id')) {
      context.handle(_titleIdMeta,
          titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta));
    } else if (isInserting) {
      context.missing(_titleIdMeta);
    }
    if (data.containsKey('media_type')) {
      context.handle(_mediaTypeMeta,
          mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta));
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('poster_path')) {
      context.handle(
          _posterPathMeta,
          posterPath.isAcceptableOrUnknown(
              data['poster_path']!, _posterPathMeta));
    }
    if (data.containsKey('backdrop_path')) {
      context.handle(
          _backdropPathMeta,
          backdropPath.isAcceptableOrUnknown(
              data['backdrop_path']!, _backdropPathMeta));
    }
    if (data.containsKey('title_status')) {
      context.handle(
          _titleStatusMeta,
          titleStatus.isAcceptableOrUnknown(
              data['title_status']!, _titleStatusMeta));
    }
    if (data.containsKey('runtime_minutes')) {
      context.handle(
          _runtimeMinutesMeta,
          runtimeMinutes.isAcceptableOrUnknown(
              data['runtime_minutes']!, _runtimeMinutesMeta));
    }
    if (data.containsKey('last_season')) {
      context.handle(
          _lastSeasonMeta,
          lastSeason.isAcceptableOrUnknown(
              data['last_season']!, _lastSeasonMeta));
    }
    if (data.containsKey('last_episode')) {
      context.handle(
          _lastEpisodeMeta,
          lastEpisode.isAcceptableOrUnknown(
              data['last_episode']!, _lastEpisodeMeta));
    }
    if (data.containsKey('state')) {
      context.handle(
          _stateMeta, state.isAcceptableOrUnknown(data['state']!, _stateMeta));
    }
    if (data.containsKey('is_rewatch')) {
      context.handle(_isRewatchMeta,
          isRewatch.isAcceptableOrUnknown(data['is_rewatch']!, _isRewatchMeta));
    }
    if (data.containsKey('new_episodes_since')) {
      context.handle(
          _newEpisodesSinceMeta,
          newEpisodesSince.isAcceptableOrUnknown(
              data['new_episodes_since']!, _newEpisodesSinceMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    }
    if (data.containsKey('last_progress_at')) {
      context.handle(
          _lastProgressAtMeta,
          lastProgressAt.isAcceptableOrUnknown(
              data['last_progress_at']!, _lastProgressAtMeta));
    }
    if (data.containsKey('finished_at')) {
      context.handle(
          _finishedAtMeta,
          finishedAt.isAcceptableOrUnknown(
              data['finished_at']!, _finishedAtMeta));
    }
    if (data.containsKey('seasons')) {
      context.handle(_seasonsMeta,
          seasons.isAcceptableOrUnknown(data['seasons']!, _seasonsMeta));
    }
    if (data.containsKey('watched')) {
      context.handle(_watchedMeta,
          watched.isAcceptableOrUnknown(data['watched']!, _watchedMeta));
    }
    if (data.containsKey('aired_total')) {
      context.handle(
          _airedTotalMeta,
          airedTotal.isAcceptableOrUnknown(
              data['aired_total']!, _airedTotalMeta));
    }
    if (data.containsKey('next_episode')) {
      context.handle(
          _nextEpisodeMeta,
          nextEpisode.isAcceptableOrUnknown(
              data['next_episode']!, _nextEpisodeMeta));
    }
    if (data.containsKey('last_aired')) {
      context.handle(_lastAiredMeta,
          lastAired.isAcceptableOrUnknown(data['last_aired']!, _lastAiredMeta));
    }
    if (data.containsKey('ranked')) {
      context.handle(_rankedMeta,
          ranked.isAcceptableOrUnknown(data['ranked']!, _rankedMeta));
    }
    if (data.containsKey('rank_position')) {
      context.handle(
          _rankPositionMeta,
          rankPosition.isAcceptableOrUnknown(
              data['rank_position']!, _rankPositionMeta));
    }
    if (data.containsKey('score')) {
      context.handle(
          _scoreMeta, score.isAcceptableOrUnknown(data['score']!, _scoreMeta));
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {titleId, mediaType};
  @override
  TrackingCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackingCacheData(
      titleId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}title_id'])!,
      mediaType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_type'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      posterPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}poster_path']),
      backdropPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}backdrop_path']),
      titleStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title_status']),
      runtimeMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}runtime_minutes']),
      lastSeason: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_season']),
      lastEpisode: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_episode']),
      state: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}state'])!,
      isRewatch: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_rewatch'])!,
      newEpisodesSince: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}new_episodes_since']),
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
      lastProgressAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_progress_at'])!,
      finishedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}finished_at']),
      seasons: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}seasons']),
      watched: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}watched']),
      airedTotal: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}aired_total']),
      nextEpisode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}next_episode']),
      lastAired: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_aired']),
      ranked: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}ranked'])!,
      rankPosition: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rank_position']),
      score: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}score']),
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
    );
  }

  @override
  $TrackingCacheTable createAlias(String alias) {
    return $TrackingCacheTable(attachedDatabase, alias);
  }
}

class TrackingCacheData extends DataClass
    implements Insertable<TrackingCacheData> {
  final int titleId;
  final String mediaType;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String? titleStatus;
  final int? runtimeMinutes;
  final int? lastSeason;
  final int? lastEpisode;
  final String state;
  final bool isRewatch;
  final DateTime? newEpisodesSince;
  final DateTime startedAt;
  final DateTime lastProgressAt;
  final DateTime? finishedAt;
  final String? seasons;
  final int? watched;
  final int? airedTotal;
  final String? nextEpisode;
  final String? lastAired;
  final bool ranked;
  final int? rankPosition;
  final double? score;
  final String syncStatus;
  const TrackingCacheData(
      {required this.titleId,
      required this.mediaType,
      required this.title,
      this.posterPath,
      this.backdropPath,
      this.titleStatus,
      this.runtimeMinutes,
      this.lastSeason,
      this.lastEpisode,
      required this.state,
      required this.isRewatch,
      this.newEpisodesSince,
      required this.startedAt,
      required this.lastProgressAt,
      this.finishedAt,
      this.seasons,
      this.watched,
      this.airedTotal,
      this.nextEpisode,
      this.lastAired,
      required this.ranked,
      this.rankPosition,
      this.score,
      required this.syncStatus});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['title_id'] = Variable<int>(titleId);
    map['media_type'] = Variable<String>(mediaType);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || posterPath != null) {
      map['poster_path'] = Variable<String>(posterPath);
    }
    if (!nullToAbsent || backdropPath != null) {
      map['backdrop_path'] = Variable<String>(backdropPath);
    }
    if (!nullToAbsent || titleStatus != null) {
      map['title_status'] = Variable<String>(titleStatus);
    }
    if (!nullToAbsent || runtimeMinutes != null) {
      map['runtime_minutes'] = Variable<int>(runtimeMinutes);
    }
    if (!nullToAbsent || lastSeason != null) {
      map['last_season'] = Variable<int>(lastSeason);
    }
    if (!nullToAbsent || lastEpisode != null) {
      map['last_episode'] = Variable<int>(lastEpisode);
    }
    map['state'] = Variable<String>(state);
    map['is_rewatch'] = Variable<bool>(isRewatch);
    if (!nullToAbsent || newEpisodesSince != null) {
      map['new_episodes_since'] = Variable<DateTime>(newEpisodesSince);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    map['last_progress_at'] = Variable<DateTime>(lastProgressAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    if (!nullToAbsent || seasons != null) {
      map['seasons'] = Variable<String>(seasons);
    }
    if (!nullToAbsent || watched != null) {
      map['watched'] = Variable<int>(watched);
    }
    if (!nullToAbsent || airedTotal != null) {
      map['aired_total'] = Variable<int>(airedTotal);
    }
    if (!nullToAbsent || nextEpisode != null) {
      map['next_episode'] = Variable<String>(nextEpisode);
    }
    if (!nullToAbsent || lastAired != null) {
      map['last_aired'] = Variable<String>(lastAired);
    }
    map['ranked'] = Variable<bool>(ranked);
    if (!nullToAbsent || rankPosition != null) {
      map['rank_position'] = Variable<int>(rankPosition);
    }
    if (!nullToAbsent || score != null) {
      map['score'] = Variable<double>(score);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  TrackingCacheCompanion toCompanion(bool nullToAbsent) {
    return TrackingCacheCompanion(
      titleId: Value(titleId),
      mediaType: Value(mediaType),
      title: Value(title),
      posterPath: posterPath == null && nullToAbsent
          ? const Value.absent()
          : Value(posterPath),
      backdropPath: backdropPath == null && nullToAbsent
          ? const Value.absent()
          : Value(backdropPath),
      titleStatus: titleStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(titleStatus),
      runtimeMinutes: runtimeMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(runtimeMinutes),
      lastSeason: lastSeason == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeason),
      lastEpisode: lastEpisode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastEpisode),
      state: Value(state),
      isRewatch: Value(isRewatch),
      newEpisodesSince: newEpisodesSince == null && nullToAbsent
          ? const Value.absent()
          : Value(newEpisodesSince),
      startedAt: Value(startedAt),
      lastProgressAt: Value(lastProgressAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      seasons: seasons == null && nullToAbsent
          ? const Value.absent()
          : Value(seasons),
      watched: watched == null && nullToAbsent
          ? const Value.absent()
          : Value(watched),
      airedTotal: airedTotal == null && nullToAbsent
          ? const Value.absent()
          : Value(airedTotal),
      nextEpisode: nextEpisode == null && nullToAbsent
          ? const Value.absent()
          : Value(nextEpisode),
      lastAired: lastAired == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAired),
      ranked: Value(ranked),
      rankPosition: rankPosition == null && nullToAbsent
          ? const Value.absent()
          : Value(rankPosition),
      score:
          score == null && nullToAbsent ? const Value.absent() : Value(score),
      syncStatus: Value(syncStatus),
    );
  }

  factory TrackingCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackingCacheData(
      titleId: serializer.fromJson<int>(json['titleId']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      title: serializer.fromJson<String>(json['title']),
      posterPath: serializer.fromJson<String?>(json['posterPath']),
      backdropPath: serializer.fromJson<String?>(json['backdropPath']),
      titleStatus: serializer.fromJson<String?>(json['titleStatus']),
      runtimeMinutes: serializer.fromJson<int?>(json['runtimeMinutes']),
      lastSeason: serializer.fromJson<int?>(json['lastSeason']),
      lastEpisode: serializer.fromJson<int?>(json['lastEpisode']),
      state: serializer.fromJson<String>(json['state']),
      isRewatch: serializer.fromJson<bool>(json['isRewatch']),
      newEpisodesSince:
          serializer.fromJson<DateTime?>(json['newEpisodesSince']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      lastProgressAt: serializer.fromJson<DateTime>(json['lastProgressAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
      seasons: serializer.fromJson<String?>(json['seasons']),
      watched: serializer.fromJson<int?>(json['watched']),
      airedTotal: serializer.fromJson<int?>(json['airedTotal']),
      nextEpisode: serializer.fromJson<String?>(json['nextEpisode']),
      lastAired: serializer.fromJson<String?>(json['lastAired']),
      ranked: serializer.fromJson<bool>(json['ranked']),
      rankPosition: serializer.fromJson<int?>(json['rankPosition']),
      score: serializer.fromJson<double?>(json['score']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'titleId': serializer.toJson<int>(titleId),
      'mediaType': serializer.toJson<String>(mediaType),
      'title': serializer.toJson<String>(title),
      'posterPath': serializer.toJson<String?>(posterPath),
      'backdropPath': serializer.toJson<String?>(backdropPath),
      'titleStatus': serializer.toJson<String?>(titleStatus),
      'runtimeMinutes': serializer.toJson<int?>(runtimeMinutes),
      'lastSeason': serializer.toJson<int?>(lastSeason),
      'lastEpisode': serializer.toJson<int?>(lastEpisode),
      'state': serializer.toJson<String>(state),
      'isRewatch': serializer.toJson<bool>(isRewatch),
      'newEpisodesSince': serializer.toJson<DateTime?>(newEpisodesSince),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'lastProgressAt': serializer.toJson<DateTime>(lastProgressAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'seasons': serializer.toJson<String?>(seasons),
      'watched': serializer.toJson<int?>(watched),
      'airedTotal': serializer.toJson<int?>(airedTotal),
      'nextEpisode': serializer.toJson<String?>(nextEpisode),
      'lastAired': serializer.toJson<String?>(lastAired),
      'ranked': serializer.toJson<bool>(ranked),
      'rankPosition': serializer.toJson<int?>(rankPosition),
      'score': serializer.toJson<double?>(score),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  TrackingCacheData copyWith(
          {int? titleId,
          String? mediaType,
          String? title,
          Value<String?> posterPath = const Value.absent(),
          Value<String?> backdropPath = const Value.absent(),
          Value<String?> titleStatus = const Value.absent(),
          Value<int?> runtimeMinutes = const Value.absent(),
          Value<int?> lastSeason = const Value.absent(),
          Value<int?> lastEpisode = const Value.absent(),
          String? state,
          bool? isRewatch,
          Value<DateTime?> newEpisodesSince = const Value.absent(),
          DateTime? startedAt,
          DateTime? lastProgressAt,
          Value<DateTime?> finishedAt = const Value.absent(),
          Value<String?> seasons = const Value.absent(),
          Value<int?> watched = const Value.absent(),
          Value<int?> airedTotal = const Value.absent(),
          Value<String?> nextEpisode = const Value.absent(),
          Value<String?> lastAired = const Value.absent(),
          bool? ranked,
          Value<int?> rankPosition = const Value.absent(),
          Value<double?> score = const Value.absent(),
          String? syncStatus}) =>
      TrackingCacheData(
        titleId: titleId ?? this.titleId,
        mediaType: mediaType ?? this.mediaType,
        title: title ?? this.title,
        posterPath: posterPath.present ? posterPath.value : this.posterPath,
        backdropPath:
            backdropPath.present ? backdropPath.value : this.backdropPath,
        titleStatus: titleStatus.present ? titleStatus.value : this.titleStatus,
        runtimeMinutes:
            runtimeMinutes.present ? runtimeMinutes.value : this.runtimeMinutes,
        lastSeason: lastSeason.present ? lastSeason.value : this.lastSeason,
        lastEpisode: lastEpisode.present ? lastEpisode.value : this.lastEpisode,
        state: state ?? this.state,
        isRewatch: isRewatch ?? this.isRewatch,
        newEpisodesSince: newEpisodesSince.present
            ? newEpisodesSince.value
            : this.newEpisodesSince,
        startedAt: startedAt ?? this.startedAt,
        lastProgressAt: lastProgressAt ?? this.lastProgressAt,
        finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
        seasons: seasons.present ? seasons.value : this.seasons,
        watched: watched.present ? watched.value : this.watched,
        airedTotal: airedTotal.present ? airedTotal.value : this.airedTotal,
        nextEpisode: nextEpisode.present ? nextEpisode.value : this.nextEpisode,
        lastAired: lastAired.present ? lastAired.value : this.lastAired,
        ranked: ranked ?? this.ranked,
        rankPosition:
            rankPosition.present ? rankPosition.value : this.rankPosition,
        score: score.present ? score.value : this.score,
        syncStatus: syncStatus ?? this.syncStatus,
      );
  TrackingCacheData copyWithCompanion(TrackingCacheCompanion data) {
    return TrackingCacheData(
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      title: data.title.present ? data.title.value : this.title,
      posterPath:
          data.posterPath.present ? data.posterPath.value : this.posterPath,
      backdropPath: data.backdropPath.present
          ? data.backdropPath.value
          : this.backdropPath,
      titleStatus:
          data.titleStatus.present ? data.titleStatus.value : this.titleStatus,
      runtimeMinutes: data.runtimeMinutes.present
          ? data.runtimeMinutes.value
          : this.runtimeMinutes,
      lastSeason:
          data.lastSeason.present ? data.lastSeason.value : this.lastSeason,
      lastEpisode:
          data.lastEpisode.present ? data.lastEpisode.value : this.lastEpisode,
      state: data.state.present ? data.state.value : this.state,
      isRewatch: data.isRewatch.present ? data.isRewatch.value : this.isRewatch,
      newEpisodesSince: data.newEpisodesSince.present
          ? data.newEpisodesSince.value
          : this.newEpisodesSince,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      lastProgressAt: data.lastProgressAt.present
          ? data.lastProgressAt.value
          : this.lastProgressAt,
      finishedAt:
          data.finishedAt.present ? data.finishedAt.value : this.finishedAt,
      seasons: data.seasons.present ? data.seasons.value : this.seasons,
      watched: data.watched.present ? data.watched.value : this.watched,
      airedTotal:
          data.airedTotal.present ? data.airedTotal.value : this.airedTotal,
      nextEpisode:
          data.nextEpisode.present ? data.nextEpisode.value : this.nextEpisode,
      lastAired: data.lastAired.present ? data.lastAired.value : this.lastAired,
      ranked: data.ranked.present ? data.ranked.value : this.ranked,
      rankPosition: data.rankPosition.present
          ? data.rankPosition.value
          : this.rankPosition,
      score: data.score.present ? data.score.value : this.score,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackingCacheData(')
          ..write('titleId: $titleId, ')
          ..write('mediaType: $mediaType, ')
          ..write('title: $title, ')
          ..write('posterPath: $posterPath, ')
          ..write('backdropPath: $backdropPath, ')
          ..write('titleStatus: $titleStatus, ')
          ..write('runtimeMinutes: $runtimeMinutes, ')
          ..write('lastSeason: $lastSeason, ')
          ..write('lastEpisode: $lastEpisode, ')
          ..write('state: $state, ')
          ..write('isRewatch: $isRewatch, ')
          ..write('newEpisodesSince: $newEpisodesSince, ')
          ..write('startedAt: $startedAt, ')
          ..write('lastProgressAt: $lastProgressAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('seasons: $seasons, ')
          ..write('watched: $watched, ')
          ..write('airedTotal: $airedTotal, ')
          ..write('nextEpisode: $nextEpisode, ')
          ..write('lastAired: $lastAired, ')
          ..write('ranked: $ranked, ')
          ..write('rankPosition: $rankPosition, ')
          ..write('score: $score, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        titleId,
        mediaType,
        title,
        posterPath,
        backdropPath,
        titleStatus,
        runtimeMinutes,
        lastSeason,
        lastEpisode,
        state,
        isRewatch,
        newEpisodesSince,
        startedAt,
        lastProgressAt,
        finishedAt,
        seasons,
        watched,
        airedTotal,
        nextEpisode,
        lastAired,
        ranked,
        rankPosition,
        score,
        syncStatus
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackingCacheData &&
          other.titleId == this.titleId &&
          other.mediaType == this.mediaType &&
          other.title == this.title &&
          other.posterPath == this.posterPath &&
          other.backdropPath == this.backdropPath &&
          other.titleStatus == this.titleStatus &&
          other.runtimeMinutes == this.runtimeMinutes &&
          other.lastSeason == this.lastSeason &&
          other.lastEpisode == this.lastEpisode &&
          other.state == this.state &&
          other.isRewatch == this.isRewatch &&
          other.newEpisodesSince == this.newEpisodesSince &&
          other.startedAt == this.startedAt &&
          other.lastProgressAt == this.lastProgressAt &&
          other.finishedAt == this.finishedAt &&
          other.seasons == this.seasons &&
          other.watched == this.watched &&
          other.airedTotal == this.airedTotal &&
          other.nextEpisode == this.nextEpisode &&
          other.lastAired == this.lastAired &&
          other.ranked == this.ranked &&
          other.rankPosition == this.rankPosition &&
          other.score == this.score &&
          other.syncStatus == this.syncStatus);
}

class TrackingCacheCompanion extends UpdateCompanion<TrackingCacheData> {
  final Value<int> titleId;
  final Value<String> mediaType;
  final Value<String> title;
  final Value<String?> posterPath;
  final Value<String?> backdropPath;
  final Value<String?> titleStatus;
  final Value<int?> runtimeMinutes;
  final Value<int?> lastSeason;
  final Value<int?> lastEpisode;
  final Value<String> state;
  final Value<bool> isRewatch;
  final Value<DateTime?> newEpisodesSince;
  final Value<DateTime> startedAt;
  final Value<DateTime> lastProgressAt;
  final Value<DateTime?> finishedAt;
  final Value<String?> seasons;
  final Value<int?> watched;
  final Value<int?> airedTotal;
  final Value<String?> nextEpisode;
  final Value<String?> lastAired;
  final Value<bool> ranked;
  final Value<int?> rankPosition;
  final Value<double?> score;
  final Value<String> syncStatus;
  final Value<int> rowid;
  const TrackingCacheCompanion({
    this.titleId = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.title = const Value.absent(),
    this.posterPath = const Value.absent(),
    this.backdropPath = const Value.absent(),
    this.titleStatus = const Value.absent(),
    this.runtimeMinutes = const Value.absent(),
    this.lastSeason = const Value.absent(),
    this.lastEpisode = const Value.absent(),
    this.state = const Value.absent(),
    this.isRewatch = const Value.absent(),
    this.newEpisodesSince = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.lastProgressAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.seasons = const Value.absent(),
    this.watched = const Value.absent(),
    this.airedTotal = const Value.absent(),
    this.nextEpisode = const Value.absent(),
    this.lastAired = const Value.absent(),
    this.ranked = const Value.absent(),
    this.rankPosition = const Value.absent(),
    this.score = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrackingCacheCompanion.insert({
    required int titleId,
    required String mediaType,
    required String title,
    this.posterPath = const Value.absent(),
    this.backdropPath = const Value.absent(),
    this.titleStatus = const Value.absent(),
    this.runtimeMinutes = const Value.absent(),
    this.lastSeason = const Value.absent(),
    this.lastEpisode = const Value.absent(),
    this.state = const Value.absent(),
    this.isRewatch = const Value.absent(),
    this.newEpisodesSince = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.lastProgressAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.seasons = const Value.absent(),
    this.watched = const Value.absent(),
    this.airedTotal = const Value.absent(),
    this.nextEpisode = const Value.absent(),
    this.lastAired = const Value.absent(),
    this.ranked = const Value.absent(),
    this.rankPosition = const Value.absent(),
    this.score = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : titleId = Value(titleId),
        mediaType = Value(mediaType),
        title = Value(title);
  static Insertable<TrackingCacheData> custom({
    Expression<int>? titleId,
    Expression<String>? mediaType,
    Expression<String>? title,
    Expression<String>? posterPath,
    Expression<String>? backdropPath,
    Expression<String>? titleStatus,
    Expression<int>? runtimeMinutes,
    Expression<int>? lastSeason,
    Expression<int>? lastEpisode,
    Expression<String>? state,
    Expression<bool>? isRewatch,
    Expression<DateTime>? newEpisodesSince,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? lastProgressAt,
    Expression<DateTime>? finishedAt,
    Expression<String>? seasons,
    Expression<int>? watched,
    Expression<int>? airedTotal,
    Expression<String>? nextEpisode,
    Expression<String>? lastAired,
    Expression<bool>? ranked,
    Expression<int>? rankPosition,
    Expression<double>? score,
    Expression<String>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (titleId != null) 'title_id': titleId,
      if (mediaType != null) 'media_type': mediaType,
      if (title != null) 'title': title,
      if (posterPath != null) 'poster_path': posterPath,
      if (backdropPath != null) 'backdrop_path': backdropPath,
      if (titleStatus != null) 'title_status': titleStatus,
      if (runtimeMinutes != null) 'runtime_minutes': runtimeMinutes,
      if (lastSeason != null) 'last_season': lastSeason,
      if (lastEpisode != null) 'last_episode': lastEpisode,
      if (state != null) 'state': state,
      if (isRewatch != null) 'is_rewatch': isRewatch,
      if (newEpisodesSince != null) 'new_episodes_since': newEpisodesSince,
      if (startedAt != null) 'started_at': startedAt,
      if (lastProgressAt != null) 'last_progress_at': lastProgressAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (seasons != null) 'seasons': seasons,
      if (watched != null) 'watched': watched,
      if (airedTotal != null) 'aired_total': airedTotal,
      if (nextEpisode != null) 'next_episode': nextEpisode,
      if (lastAired != null) 'last_aired': lastAired,
      if (ranked != null) 'ranked': ranked,
      if (rankPosition != null) 'rank_position': rankPosition,
      if (score != null) 'score': score,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrackingCacheCompanion copyWith(
      {Value<int>? titleId,
      Value<String>? mediaType,
      Value<String>? title,
      Value<String?>? posterPath,
      Value<String?>? backdropPath,
      Value<String?>? titleStatus,
      Value<int?>? runtimeMinutes,
      Value<int?>? lastSeason,
      Value<int?>? lastEpisode,
      Value<String>? state,
      Value<bool>? isRewatch,
      Value<DateTime?>? newEpisodesSince,
      Value<DateTime>? startedAt,
      Value<DateTime>? lastProgressAt,
      Value<DateTime?>? finishedAt,
      Value<String?>? seasons,
      Value<int?>? watched,
      Value<int?>? airedTotal,
      Value<String?>? nextEpisode,
      Value<String?>? lastAired,
      Value<bool>? ranked,
      Value<int?>? rankPosition,
      Value<double?>? score,
      Value<String>? syncStatus,
      Value<int>? rowid}) {
    return TrackingCacheCompanion(
      titleId: titleId ?? this.titleId,
      mediaType: mediaType ?? this.mediaType,
      title: title ?? this.title,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      titleStatus: titleStatus ?? this.titleStatus,
      runtimeMinutes: runtimeMinutes ?? this.runtimeMinutes,
      lastSeason: lastSeason ?? this.lastSeason,
      lastEpisode: lastEpisode ?? this.lastEpisode,
      state: state ?? this.state,
      isRewatch: isRewatch ?? this.isRewatch,
      newEpisodesSince: newEpisodesSince ?? this.newEpisodesSince,
      startedAt: startedAt ?? this.startedAt,
      lastProgressAt: lastProgressAt ?? this.lastProgressAt,
      finishedAt: finishedAt ?? this.finishedAt,
      seasons: seasons ?? this.seasons,
      watched: watched ?? this.watched,
      airedTotal: airedTotal ?? this.airedTotal,
      nextEpisode: nextEpisode ?? this.nextEpisode,
      lastAired: lastAired ?? this.lastAired,
      ranked: ranked ?? this.ranked,
      rankPosition: rankPosition ?? this.rankPosition,
      score: score ?? this.score,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (titleId.present) {
      map['title_id'] = Variable<int>(titleId.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (posterPath.present) {
      map['poster_path'] = Variable<String>(posterPath.value);
    }
    if (backdropPath.present) {
      map['backdrop_path'] = Variable<String>(backdropPath.value);
    }
    if (titleStatus.present) {
      map['title_status'] = Variable<String>(titleStatus.value);
    }
    if (runtimeMinutes.present) {
      map['runtime_minutes'] = Variable<int>(runtimeMinutes.value);
    }
    if (lastSeason.present) {
      map['last_season'] = Variable<int>(lastSeason.value);
    }
    if (lastEpisode.present) {
      map['last_episode'] = Variable<int>(lastEpisode.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (isRewatch.present) {
      map['is_rewatch'] = Variable<bool>(isRewatch.value);
    }
    if (newEpisodesSince.present) {
      map['new_episodes_since'] = Variable<DateTime>(newEpisodesSince.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (lastProgressAt.present) {
      map['last_progress_at'] = Variable<DateTime>(lastProgressAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (seasons.present) {
      map['seasons'] = Variable<String>(seasons.value);
    }
    if (watched.present) {
      map['watched'] = Variable<int>(watched.value);
    }
    if (airedTotal.present) {
      map['aired_total'] = Variable<int>(airedTotal.value);
    }
    if (nextEpisode.present) {
      map['next_episode'] = Variable<String>(nextEpisode.value);
    }
    if (lastAired.present) {
      map['last_aired'] = Variable<String>(lastAired.value);
    }
    if (ranked.present) {
      map['ranked'] = Variable<bool>(ranked.value);
    }
    if (rankPosition.present) {
      map['rank_position'] = Variable<int>(rankPosition.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackingCacheCompanion(')
          ..write('titleId: $titleId, ')
          ..write('mediaType: $mediaType, ')
          ..write('title: $title, ')
          ..write('posterPath: $posterPath, ')
          ..write('backdropPath: $backdropPath, ')
          ..write('titleStatus: $titleStatus, ')
          ..write('runtimeMinutes: $runtimeMinutes, ')
          ..write('lastSeason: $lastSeason, ')
          ..write('lastEpisode: $lastEpisode, ')
          ..write('state: $state, ')
          ..write('isRewatch: $isRewatch, ')
          ..write('newEpisodesSince: $newEpisodesSince, ')
          ..write('startedAt: $startedAt, ')
          ..write('lastProgressAt: $lastProgressAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('seasons: $seasons, ')
          ..write('watched: $watched, ')
          ..write('airedTotal: $airedTotal, ')
          ..write('nextEpisode: $nextEpisode, ')
          ..write('lastAired: $lastAired, ')
          ..write('ranked: $ranked, ')
          ..write('rankPosition: $rankPosition, ')
          ..write('score: $score, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpisodeCacheTable extends EpisodeCache
    with TableInfo<$EpisodeCacheTable, EpisodeCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodeCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _titleIdMeta =
      const VerificationMeta('titleId');
  @override
  late final GeneratedColumn<int> titleId = GeneratedColumn<int>(
      'title_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _seasonNumberMeta =
      const VerificationMeta('seasonNumber');
  @override
  late final GeneratedColumn<int> seasonNumber = GeneratedColumn<int>(
      'season_number', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fetchedAtMeta =
      const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
      'fetched_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [titleId, seasonNumber, json, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episode_cache';
  @override
  VerificationContext validateIntegrity(Insertable<EpisodeCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('title_id')) {
      context.handle(_titleIdMeta,
          titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta));
    } else if (isInserting) {
      context.missing(_titleIdMeta);
    }
    if (data.containsKey('season_number')) {
      context.handle(
          _seasonNumberMeta,
          seasonNumber.isAcceptableOrUnknown(
              data['season_number']!, _seasonNumberMeta));
    } else if (isInserting) {
      context.missing(_seasonNumberMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta,
          fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {titleId, seasonNumber};
  @override
  EpisodeCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpisodeCacheData(
      titleId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}title_id'])!,
      seasonNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}season_number'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
      fetchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fetched_at'])!,
    );
  }

  @override
  $EpisodeCacheTable createAlias(String alias) {
    return $EpisodeCacheTable(attachedDatabase, alias);
  }
}

class EpisodeCacheData extends DataClass
    implements Insertable<EpisodeCacheData> {
  final int titleId;
  final int seasonNumber;
  final String json;
  final DateTime fetchedAt;
  const EpisodeCacheData(
      {required this.titleId,
      required this.seasonNumber,
      required this.json,
      required this.fetchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['title_id'] = Variable<int>(titleId);
    map['season_number'] = Variable<int>(seasonNumber);
    map['json'] = Variable<String>(json);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  EpisodeCacheCompanion toCompanion(bool nullToAbsent) {
    return EpisodeCacheCompanion(
      titleId: Value(titleId),
      seasonNumber: Value(seasonNumber),
      json: Value(json),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory EpisodeCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpisodeCacheData(
      titleId: serializer.fromJson<int>(json['titleId']),
      seasonNumber: serializer.fromJson<int>(json['seasonNumber']),
      json: serializer.fromJson<String>(json['json']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'titleId': serializer.toJson<int>(titleId),
      'seasonNumber': serializer.toJson<int>(seasonNumber),
      'json': serializer.toJson<String>(json),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  EpisodeCacheData copyWith(
          {int? titleId,
          int? seasonNumber,
          String? json,
          DateTime? fetchedAt}) =>
      EpisodeCacheData(
        titleId: titleId ?? this.titleId,
        seasonNumber: seasonNumber ?? this.seasonNumber,
        json: json ?? this.json,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
  EpisodeCacheData copyWithCompanion(EpisodeCacheCompanion data) {
    return EpisodeCacheData(
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      seasonNumber: data.seasonNumber.present
          ? data.seasonNumber.value
          : this.seasonNumber,
      json: data.json.present ? data.json.value : this.json,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeCacheData(')
          ..write('titleId: $titleId, ')
          ..write('seasonNumber: $seasonNumber, ')
          ..write('json: $json, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(titleId, seasonNumber, json, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpisodeCacheData &&
          other.titleId == this.titleId &&
          other.seasonNumber == this.seasonNumber &&
          other.json == this.json &&
          other.fetchedAt == this.fetchedAt);
}

class EpisodeCacheCompanion extends UpdateCompanion<EpisodeCacheData> {
  final Value<int> titleId;
  final Value<int> seasonNumber;
  final Value<String> json;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const EpisodeCacheCompanion({
    this.titleId = const Value.absent(),
    this.seasonNumber = const Value.absent(),
    this.json = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpisodeCacheCompanion.insert({
    required int titleId,
    required int seasonNumber,
    required String json,
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : titleId = Value(titleId),
        seasonNumber = Value(seasonNumber),
        json = Value(json);
  static Insertable<EpisodeCacheData> custom({
    Expression<int>? titleId,
    Expression<int>? seasonNumber,
    Expression<String>? json,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (titleId != null) 'title_id': titleId,
      if (seasonNumber != null) 'season_number': seasonNumber,
      if (json != null) 'json': json,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpisodeCacheCompanion copyWith(
      {Value<int>? titleId,
      Value<int>? seasonNumber,
      Value<String>? json,
      Value<DateTime>? fetchedAt,
      Value<int>? rowid}) {
    return EpisodeCacheCompanion(
      titleId: titleId ?? this.titleId,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      json: json ?? this.json,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (titleId.present) {
      map['title_id'] = Variable<int>(titleId.value);
    }
    if (seasonNumber.present) {
      map['season_number'] = Variable<int>(seasonNumber.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeCacheCompanion(')
          ..write('titleId: $titleId, ')
          ..write('seasonNumber: $seasonNumber, ')
          ..write('json: $json, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedTitlesTable cachedTitles = $CachedTitlesTable(this);
  late final $LocalRankingsTable localRankings = $LocalRankingsTable(this);
  late final $PendingMutationsTable pendingMutations =
      $PendingMutationsTable(this);
  late final $WatchlistCacheTable watchlistCache = $WatchlistCacheTable(this);
  late final $GamificationCacheTable gamificationCache =
      $GamificationCacheTable(this);
  late final $ExploreCacheTable exploreCache = $ExploreCacheTable(this);
  late final $TrackingCacheTable trackingCache = $TrackingCacheTable(this);
  late final $EpisodeCacheTable episodeCache = $EpisodeCacheTable(this);
  late final LocalRankingDao localRankingDao =
      LocalRankingDao(this as AppDatabase);
  late final LocalTitleDao localTitleDao = LocalTitleDao(this as AppDatabase);
  late final PendingMutationDao pendingMutationDao =
      PendingMutationDao(this as AppDatabase);
  late final ExploreCacheDao exploreCacheDao =
      ExploreCacheDao(this as AppDatabase);
  late final TrackingCacheDao trackingCacheDao =
      TrackingCacheDao(this as AppDatabase);
  late final EpisodeCacheDao episodeCacheDao =
      EpisodeCacheDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        cachedTitles,
        localRankings,
        pendingMutations,
        watchlistCache,
        gamificationCache,
        exploreCache,
        trackingCache,
        episodeCache
      ];
}

typedef $$CachedTitlesTableCreateCompanionBuilder = CachedTitlesCompanion
    Function({
  required int id,
  required String title,
  required String mediaType,
  Value<String?> posterPath,
  Value<String?> backdropPath,
  Value<String?> overview,
  Value<String?> releaseDate,
  Value<String?> genres,
  Value<String?> streamingServices,
  Value<bool> isAnime,
  Value<int?> totalSeasons,
  Value<int?> totalEpisodes,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$CachedTitlesTableUpdateCompanionBuilder = CachedTitlesCompanion
    Function({
  Value<int> id,
  Value<String> title,
  Value<String> mediaType,
  Value<String?> posterPath,
  Value<String?> backdropPath,
  Value<String?> overview,
  Value<String?> releaseDate,
  Value<String?> genres,
  Value<String?> streamingServices,
  Value<bool> isAnime,
  Value<int?> totalSeasons,
  Value<int?> totalEpisodes,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$CachedTitlesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedTitlesTable> {
  $$CachedTitlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get backdropPath => $composableBuilder(
      column: $table.backdropPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get overview => $composableBuilder(
      column: $table.overview, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get releaseDate => $composableBuilder(
      column: $table.releaseDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get genres => $composableBuilder(
      column: $table.genres, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get streamingServices => $composableBuilder(
      column: $table.streamingServices,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isAnime => $composableBuilder(
      column: $table.isAnime, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalSeasons => $composableBuilder(
      column: $table.totalSeasons, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalEpisodes => $composableBuilder(
      column: $table.totalEpisodes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedTitlesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedTitlesTable> {
  $$CachedTitlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get backdropPath => $composableBuilder(
      column: $table.backdropPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get overview => $composableBuilder(
      column: $table.overview, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get releaseDate => $composableBuilder(
      column: $table.releaseDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get genres => $composableBuilder(
      column: $table.genres, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get streamingServices => $composableBuilder(
      column: $table.streamingServices,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isAnime => $composableBuilder(
      column: $table.isAnime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalSeasons => $composableBuilder(
      column: $table.totalSeasons,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalEpisodes => $composableBuilder(
      column: $table.totalEpisodes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedTitlesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedTitlesTable> {
  $$CachedTitlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => column);

  GeneratedColumn<String> get backdropPath => $composableBuilder(
      column: $table.backdropPath, builder: (column) => column);

  GeneratedColumn<String> get overview =>
      $composableBuilder(column: $table.overview, builder: (column) => column);

  GeneratedColumn<String> get releaseDate => $composableBuilder(
      column: $table.releaseDate, builder: (column) => column);

  GeneratedColumn<String> get genres =>
      $composableBuilder(column: $table.genres, builder: (column) => column);

  GeneratedColumn<String> get streamingServices => $composableBuilder(
      column: $table.streamingServices, builder: (column) => column);

  GeneratedColumn<bool> get isAnime =>
      $composableBuilder(column: $table.isAnime, builder: (column) => column);

  GeneratedColumn<int> get totalSeasons => $composableBuilder(
      column: $table.totalSeasons, builder: (column) => column);

  GeneratedColumn<int> get totalEpisodes => $composableBuilder(
      column: $table.totalEpisodes, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CachedTitlesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedTitlesTable,
    CachedTitle,
    $$CachedTitlesTableFilterComposer,
    $$CachedTitlesTableOrderingComposer,
    $$CachedTitlesTableAnnotationComposer,
    $$CachedTitlesTableCreateCompanionBuilder,
    $$CachedTitlesTableUpdateCompanionBuilder,
    (
      CachedTitle,
      BaseReferences<_$AppDatabase, $CachedTitlesTable, CachedTitle>
    ),
    CachedTitle,
    PrefetchHooks Function()> {
  $$CachedTitlesTableTableManager(_$AppDatabase db, $CachedTitlesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedTitlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedTitlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedTitlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> mediaType = const Value.absent(),
            Value<String?> posterPath = const Value.absent(),
            Value<String?> backdropPath = const Value.absent(),
            Value<String?> overview = const Value.absent(),
            Value<String?> releaseDate = const Value.absent(),
            Value<String?> genres = const Value.absent(),
            Value<String?> streamingServices = const Value.absent(),
            Value<bool> isAnime = const Value.absent(),
            Value<int?> totalSeasons = const Value.absent(),
            Value<int?> totalEpisodes = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedTitlesCompanion(
            id: id,
            title: title,
            mediaType: mediaType,
            posterPath: posterPath,
            backdropPath: backdropPath,
            overview: overview,
            releaseDate: releaseDate,
            genres: genres,
            streamingServices: streamingServices,
            isAnime: isAnime,
            totalSeasons: totalSeasons,
            totalEpisodes: totalEpisodes,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int id,
            required String title,
            required String mediaType,
            Value<String?> posterPath = const Value.absent(),
            Value<String?> backdropPath = const Value.absent(),
            Value<String?> overview = const Value.absent(),
            Value<String?> releaseDate = const Value.absent(),
            Value<String?> genres = const Value.absent(),
            Value<String?> streamingServices = const Value.absent(),
            Value<bool> isAnime = const Value.absent(),
            Value<int?> totalSeasons = const Value.absent(),
            Value<int?> totalEpisodes = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedTitlesCompanion.insert(
            id: id,
            title: title,
            mediaType: mediaType,
            posterPath: posterPath,
            backdropPath: backdropPath,
            overview: overview,
            releaseDate: releaseDate,
            genres: genres,
            streamingServices: streamingServices,
            isAnime: isAnime,
            totalSeasons: totalSeasons,
            totalEpisodes: totalEpisodes,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CachedTitlesTable, CachedTitle>(table),
                    BaseReferences<_$AppDatabase, $CachedTitlesTable,
                        CachedTitle>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedTitlesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedTitlesTable,
    CachedTitle,
    $$CachedTitlesTableFilterComposer,
    $$CachedTitlesTableOrderingComposer,
    $$CachedTitlesTableAnnotationComposer,
    $$CachedTitlesTableCreateCompanionBuilder,
    $$CachedTitlesTableUpdateCompanionBuilder,
    (
      CachedTitle,
      BaseReferences<_$AppDatabase, $CachedTitlesTable, CachedTitle>
    ),
    CachedTitle,
    PrefetchHooks Function()>;
typedef $$LocalRankingsTableCreateCompanionBuilder = LocalRankingsCompanion
    Function({
  required int showId,
  required String mediaType,
  required String title,
  Value<String?> posterPath,
  required int rankPosition,
  required double calculatedScore,
  Value<String?> bracket,
  Value<String?> favoriteCharacter,
  Value<String> syncStatus,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$LocalRankingsTableUpdateCompanionBuilder = LocalRankingsCompanion
    Function({
  Value<int> showId,
  Value<String> mediaType,
  Value<String> title,
  Value<String?> posterPath,
  Value<int> rankPosition,
  Value<double> calculatedScore,
  Value<String?> bracket,
  Value<String?> favoriteCharacter,
  Value<String> syncStatus,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$LocalRankingsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalRankingsTable> {
  $$LocalRankingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get showId => $composableBuilder(
      column: $table.showId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rankPosition => $composableBuilder(
      column: $table.rankPosition, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get calculatedScore => $composableBuilder(
      column: $table.calculatedScore,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bracket => $composableBuilder(
      column: $table.bracket, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get favoriteCharacter => $composableBuilder(
      column: $table.favoriteCharacter,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalRankingsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalRankingsTable> {
  $$LocalRankingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get showId => $composableBuilder(
      column: $table.showId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rankPosition => $composableBuilder(
      column: $table.rankPosition,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get calculatedScore => $composableBuilder(
      column: $table.calculatedScore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bracket => $composableBuilder(
      column: $table.bracket, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get favoriteCharacter => $composableBuilder(
      column: $table.favoriteCharacter,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalRankingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalRankingsTable> {
  $$LocalRankingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get showId =>
      $composableBuilder(column: $table.showId, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => column);

  GeneratedColumn<int> get rankPosition => $composableBuilder(
      column: $table.rankPosition, builder: (column) => column);

  GeneratedColumn<double> get calculatedScore => $composableBuilder(
      column: $table.calculatedScore, builder: (column) => column);

  GeneratedColumn<String> get bracket =>
      $composableBuilder(column: $table.bracket, builder: (column) => column);

  GeneratedColumn<String> get favoriteCharacter => $composableBuilder(
      column: $table.favoriteCharacter, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalRankingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalRankingsTable,
    LocalRanking,
    $$LocalRankingsTableFilterComposer,
    $$LocalRankingsTableOrderingComposer,
    $$LocalRankingsTableAnnotationComposer,
    $$LocalRankingsTableCreateCompanionBuilder,
    $$LocalRankingsTableUpdateCompanionBuilder,
    (
      LocalRanking,
      BaseReferences<_$AppDatabase, $LocalRankingsTable, LocalRanking>
    ),
    LocalRanking,
    PrefetchHooks Function()> {
  $$LocalRankingsTableTableManager(_$AppDatabase db, $LocalRankingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalRankingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalRankingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalRankingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> showId = const Value.absent(),
            Value<String> mediaType = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> posterPath = const Value.absent(),
            Value<int> rankPosition = const Value.absent(),
            Value<double> calculatedScore = const Value.absent(),
            Value<String?> bracket = const Value.absent(),
            Value<String?> favoriteCharacter = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalRankingsCompanion(
            showId: showId,
            mediaType: mediaType,
            title: title,
            posterPath: posterPath,
            rankPosition: rankPosition,
            calculatedScore: calculatedScore,
            bracket: bracket,
            favoriteCharacter: favoriteCharacter,
            syncStatus: syncStatus,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int showId,
            required String mediaType,
            required String title,
            Value<String?> posterPath = const Value.absent(),
            required int rankPosition,
            required double calculatedScore,
            Value<String?> bracket = const Value.absent(),
            Value<String?> favoriteCharacter = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalRankingsCompanion.insert(
            showId: showId,
            mediaType: mediaType,
            title: title,
            posterPath: posterPath,
            rankPosition: rankPosition,
            calculatedScore: calculatedScore,
            bracket: bracket,
            favoriteCharacter: favoriteCharacter,
            syncStatus: syncStatus,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LocalRankingsTable, LocalRanking>(table),
                    BaseReferences<_$AppDatabase, $LocalRankingsTable,
                        LocalRanking>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalRankingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalRankingsTable,
    LocalRanking,
    $$LocalRankingsTableFilterComposer,
    $$LocalRankingsTableOrderingComposer,
    $$LocalRankingsTableAnnotationComposer,
    $$LocalRankingsTableCreateCompanionBuilder,
    $$LocalRankingsTableUpdateCompanionBuilder,
    (
      LocalRanking,
      BaseReferences<_$AppDatabase, $LocalRankingsTable, LocalRanking>
    ),
    LocalRanking,
    PrefetchHooks Function()>;
typedef $$PendingMutationsTableCreateCompanionBuilder
    = PendingMutationsCompanion Function({
  Value<int> seq,
  required String id,
  required String kind,
  required String payload,
  Value<DateTime> createdAt,
  Value<int> attempts,
  Value<String?> lastError,
});
typedef $$PendingMutationsTableUpdateCompanionBuilder
    = PendingMutationsCompanion Function({
  Value<int> seq,
  Value<String> id,
  Value<String> kind,
  Value<String> payload,
  Value<DateTime> createdAt,
  Value<int> attempts,
  Value<String?> lastError,
});

class $$PendingMutationsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingMutationsTable> {
  $$PendingMutationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
      column: $table.seq, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));
}

class $$PendingMutationsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingMutationsTable> {
  $$PendingMutationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
      column: $table.seq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));
}

class $$PendingMutationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingMutationsTable> {
  $$PendingMutationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$PendingMutationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PendingMutationsTable,
    PendingMutation,
    $$PendingMutationsTableFilterComposer,
    $$PendingMutationsTableOrderingComposer,
    $$PendingMutationsTableAnnotationComposer,
    $$PendingMutationsTableCreateCompanionBuilder,
    $$PendingMutationsTableUpdateCompanionBuilder,
    (
      PendingMutation,
      BaseReferences<_$AppDatabase, $PendingMutationsTable, PendingMutation>
    ),
    PendingMutation,
    PrefetchHooks Function()> {
  $$PendingMutationsTableTableManager(
      _$AppDatabase db, $PendingMutationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingMutationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingMutationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingMutationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> seq = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
          }) =>
              PendingMutationsCompanion(
            seq: seq,
            id: id,
            kind: kind,
            payload: payload,
            createdAt: createdAt,
            attempts: attempts,
            lastError: lastError,
          ),
          createCompanionCallback: ({
            Value<int> seq = const Value.absent(),
            required String id,
            required String kind,
            required String payload,
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
          }) =>
              PendingMutationsCompanion.insert(
            seq: seq,
            id: id,
            kind: kind,
            payload: payload,
            createdAt: createdAt,
            attempts: attempts,
            lastError: lastError,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PendingMutationsTable, PendingMutation>(table),
                    BaseReferences<_$AppDatabase, $PendingMutationsTable,
                        PendingMutation>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PendingMutationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PendingMutationsTable,
    PendingMutation,
    $$PendingMutationsTableFilterComposer,
    $$PendingMutationsTableOrderingComposer,
    $$PendingMutationsTableAnnotationComposer,
    $$PendingMutationsTableCreateCompanionBuilder,
    $$PendingMutationsTableUpdateCompanionBuilder,
    (
      PendingMutation,
      BaseReferences<_$AppDatabase, $PendingMutationsTable, PendingMutation>
    ),
    PendingMutation,
    PrefetchHooks Function()>;
typedef $$WatchlistCacheTableCreateCompanionBuilder = WatchlistCacheCompanion
    Function({
  required int titleId,
  required String mediaType,
  required String title,
  Value<String?> posterPath,
  Value<DateTime> savedAt,
  Value<String> syncStatus,
  Value<int> rowid,
});
typedef $$WatchlistCacheTableUpdateCompanionBuilder = WatchlistCacheCompanion
    Function({
  Value<int> titleId,
  Value<String> mediaType,
  Value<String> title,
  Value<String?> posterPath,
  Value<DateTime> savedAt,
  Value<String> syncStatus,
  Value<int> rowid,
});

class $$WatchlistCacheTableFilterComposer
    extends Composer<_$AppDatabase, $WatchlistCacheTable> {
  $$WatchlistCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get titleId => $composableBuilder(
      column: $table.titleId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get savedAt => $composableBuilder(
      column: $table.savedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));
}

class $$WatchlistCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchlistCacheTable> {
  $$WatchlistCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get titleId => $composableBuilder(
      column: $table.titleId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
      column: $table.savedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));
}

class $$WatchlistCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchlistCacheTable> {
  $$WatchlistCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => column);

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);
}

class $$WatchlistCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WatchlistCacheTable,
    WatchlistCacheData,
    $$WatchlistCacheTableFilterComposer,
    $$WatchlistCacheTableOrderingComposer,
    $$WatchlistCacheTableAnnotationComposer,
    $$WatchlistCacheTableCreateCompanionBuilder,
    $$WatchlistCacheTableUpdateCompanionBuilder,
    (
      WatchlistCacheData,
      BaseReferences<_$AppDatabase, $WatchlistCacheTable, WatchlistCacheData>
    ),
    WatchlistCacheData,
    PrefetchHooks Function()> {
  $$WatchlistCacheTableTableManager(
      _$AppDatabase db, $WatchlistCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchlistCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchlistCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchlistCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> titleId = const Value.absent(),
            Value<String> mediaType = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> posterPath = const Value.absent(),
            Value<DateTime> savedAt = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WatchlistCacheCompanion(
            titleId: titleId,
            mediaType: mediaType,
            title: title,
            posterPath: posterPath,
            savedAt: savedAt,
            syncStatus: syncStatus,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int titleId,
            required String mediaType,
            required String title,
            Value<String?> posterPath = const Value.absent(),
            Value<DateTime> savedAt = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WatchlistCacheCompanion.insert(
            titleId: titleId,
            mediaType: mediaType,
            title: title,
            posterPath: posterPath,
            savedAt: savedAt,
            syncStatus: syncStatus,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$WatchlistCacheTable, WatchlistCacheData>(
                        table),
                    BaseReferences<_$AppDatabase, $WatchlistCacheTable,
                        WatchlistCacheData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WatchlistCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WatchlistCacheTable,
    WatchlistCacheData,
    $$WatchlistCacheTableFilterComposer,
    $$WatchlistCacheTableOrderingComposer,
    $$WatchlistCacheTableAnnotationComposer,
    $$WatchlistCacheTableCreateCompanionBuilder,
    $$WatchlistCacheTableUpdateCompanionBuilder,
    (
      WatchlistCacheData,
      BaseReferences<_$AppDatabase, $WatchlistCacheTable, WatchlistCacheData>
    ),
    WatchlistCacheData,
    PrefetchHooks Function()>;
typedef $$GamificationCacheTableCreateCompanionBuilder
    = GamificationCacheCompanion Function({
  required String key,
  required String json,
  Value<DateTime> savedAt,
  Value<int> rowid,
});
typedef $$GamificationCacheTableUpdateCompanionBuilder
    = GamificationCacheCompanion Function({
  Value<String> key,
  Value<String> json,
  Value<DateTime> savedAt,
  Value<int> rowid,
});

class $$GamificationCacheTableFilterComposer
    extends Composer<_$AppDatabase, $GamificationCacheTable> {
  $$GamificationCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get savedAt => $composableBuilder(
      column: $table.savedAt, builder: (column) => ColumnFilters(column));
}

class $$GamificationCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $GamificationCacheTable> {
  $$GamificationCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
      column: $table.savedAt, builder: (column) => ColumnOrderings(column));
}

class $$GamificationCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $GamificationCacheTable> {
  $$GamificationCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);
}

class $$GamificationCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $GamificationCacheTable,
    GamificationCacheData,
    $$GamificationCacheTableFilterComposer,
    $$GamificationCacheTableOrderingComposer,
    $$GamificationCacheTableAnnotationComposer,
    $$GamificationCacheTableCreateCompanionBuilder,
    $$GamificationCacheTableUpdateCompanionBuilder,
    (
      GamificationCacheData,
      BaseReferences<_$AppDatabase, $GamificationCacheTable,
          GamificationCacheData>
    ),
    GamificationCacheData,
    PrefetchHooks Function()> {
  $$GamificationCacheTableTableManager(
      _$AppDatabase db, $GamificationCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GamificationCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GamificationCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GamificationCacheTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<DateTime> savedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GamificationCacheCompanion(
            key: key,
            json: json,
            savedAt: savedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String json,
            Value<DateTime> savedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GamificationCacheCompanion.insert(
            key: key,
            json: json,
            savedAt: savedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$GamificationCacheTable, GamificationCacheData>(
                        table),
                    BaseReferences<_$AppDatabase, $GamificationCacheTable,
                        GamificationCacheData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$GamificationCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $GamificationCacheTable,
    GamificationCacheData,
    $$GamificationCacheTableFilterComposer,
    $$GamificationCacheTableOrderingComposer,
    $$GamificationCacheTableAnnotationComposer,
    $$GamificationCacheTableCreateCompanionBuilder,
    $$GamificationCacheTableUpdateCompanionBuilder,
    (
      GamificationCacheData,
      BaseReferences<_$AppDatabase, $GamificationCacheTable,
          GamificationCacheData>
    ),
    GamificationCacheData,
    PrefetchHooks Function()>;
typedef $$ExploreCacheTableCreateCompanionBuilder = ExploreCacheCompanion
    Function({
  required String mediaType,
  required String json,
  Value<DateTime> savedAt,
  Value<int> rowid,
});
typedef $$ExploreCacheTableUpdateCompanionBuilder = ExploreCacheCompanion
    Function({
  Value<String> mediaType,
  Value<String> json,
  Value<DateTime> savedAt,
  Value<int> rowid,
});

class $$ExploreCacheTableFilterComposer
    extends Composer<_$AppDatabase, $ExploreCacheTable> {
  $$ExploreCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get savedAt => $composableBuilder(
      column: $table.savedAt, builder: (column) => ColumnFilters(column));
}

class $$ExploreCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $ExploreCacheTable> {
  $$ExploreCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
      column: $table.savedAt, builder: (column) => ColumnOrderings(column));
}

class $$ExploreCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExploreCacheTable> {
  $$ExploreCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);
}

class $$ExploreCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ExploreCacheTable,
    ExploreCacheData,
    $$ExploreCacheTableFilterComposer,
    $$ExploreCacheTableOrderingComposer,
    $$ExploreCacheTableAnnotationComposer,
    $$ExploreCacheTableCreateCompanionBuilder,
    $$ExploreCacheTableUpdateCompanionBuilder,
    (
      ExploreCacheData,
      BaseReferences<_$AppDatabase, $ExploreCacheTable, ExploreCacheData>
    ),
    ExploreCacheData,
    PrefetchHooks Function()> {
  $$ExploreCacheTableTableManager(_$AppDatabase db, $ExploreCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExploreCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExploreCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExploreCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> mediaType = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<DateTime> savedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ExploreCacheCompanion(
            mediaType: mediaType,
            json: json,
            savedAt: savedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String mediaType,
            required String json,
            Value<DateTime> savedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ExploreCacheCompanion.insert(
            mediaType: mediaType,
            json: json,
            savedAt: savedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ExploreCacheTable, ExploreCacheData>(table),
                    BaseReferences<_$AppDatabase, $ExploreCacheTable,
                        ExploreCacheData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ExploreCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ExploreCacheTable,
    ExploreCacheData,
    $$ExploreCacheTableFilterComposer,
    $$ExploreCacheTableOrderingComposer,
    $$ExploreCacheTableAnnotationComposer,
    $$ExploreCacheTableCreateCompanionBuilder,
    $$ExploreCacheTableUpdateCompanionBuilder,
    (
      ExploreCacheData,
      BaseReferences<_$AppDatabase, $ExploreCacheTable, ExploreCacheData>
    ),
    ExploreCacheData,
    PrefetchHooks Function()>;
typedef $$TrackingCacheTableCreateCompanionBuilder = TrackingCacheCompanion
    Function({
  required int titleId,
  required String mediaType,
  required String title,
  Value<String?> posterPath,
  Value<String?> backdropPath,
  Value<String?> titleStatus,
  Value<int?> runtimeMinutes,
  Value<int?> lastSeason,
  Value<int?> lastEpisode,
  Value<String> state,
  Value<bool> isRewatch,
  Value<DateTime?> newEpisodesSince,
  Value<DateTime> startedAt,
  Value<DateTime> lastProgressAt,
  Value<DateTime?> finishedAt,
  Value<String?> seasons,
  Value<int?> watched,
  Value<int?> airedTotal,
  Value<String?> nextEpisode,
  Value<String?> lastAired,
  Value<bool> ranked,
  Value<int?> rankPosition,
  Value<double?> score,
  Value<String> syncStatus,
  Value<int> rowid,
});
typedef $$TrackingCacheTableUpdateCompanionBuilder = TrackingCacheCompanion
    Function({
  Value<int> titleId,
  Value<String> mediaType,
  Value<String> title,
  Value<String?> posterPath,
  Value<String?> backdropPath,
  Value<String?> titleStatus,
  Value<int?> runtimeMinutes,
  Value<int?> lastSeason,
  Value<int?> lastEpisode,
  Value<String> state,
  Value<bool> isRewatch,
  Value<DateTime?> newEpisodesSince,
  Value<DateTime> startedAt,
  Value<DateTime> lastProgressAt,
  Value<DateTime?> finishedAt,
  Value<String?> seasons,
  Value<int?> watched,
  Value<int?> airedTotal,
  Value<String?> nextEpisode,
  Value<String?> lastAired,
  Value<bool> ranked,
  Value<int?> rankPosition,
  Value<double?> score,
  Value<String> syncStatus,
  Value<int> rowid,
});

class $$TrackingCacheTableFilterComposer
    extends Composer<_$AppDatabase, $TrackingCacheTable> {
  $$TrackingCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get titleId => $composableBuilder(
      column: $table.titleId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get backdropPath => $composableBuilder(
      column: $table.backdropPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get titleStatus => $composableBuilder(
      column: $table.titleStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get runtimeMinutes => $composableBuilder(
      column: $table.runtimeMinutes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastSeason => $composableBuilder(
      column: $table.lastSeason, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastEpisode => $composableBuilder(
      column: $table.lastEpisode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isRewatch => $composableBuilder(
      column: $table.isRewatch, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get newEpisodesSince => $composableBuilder(
      column: $table.newEpisodesSince,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastProgressAt => $composableBuilder(
      column: $table.lastProgressAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
      column: $table.finishedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get seasons => $composableBuilder(
      column: $table.seasons, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get watched => $composableBuilder(
      column: $table.watched, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get airedTotal => $composableBuilder(
      column: $table.airedTotal, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nextEpisode => $composableBuilder(
      column: $table.nextEpisode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastAired => $composableBuilder(
      column: $table.lastAired, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get ranked => $composableBuilder(
      column: $table.ranked, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rankPosition => $composableBuilder(
      column: $table.rankPosition, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get score => $composableBuilder(
      column: $table.score, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));
}

class $$TrackingCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $TrackingCacheTable> {
  $$TrackingCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get titleId => $composableBuilder(
      column: $table.titleId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get backdropPath => $composableBuilder(
      column: $table.backdropPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get titleStatus => $composableBuilder(
      column: $table.titleStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get runtimeMinutes => $composableBuilder(
      column: $table.runtimeMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastSeason => $composableBuilder(
      column: $table.lastSeason, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastEpisode => $composableBuilder(
      column: $table.lastEpisode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isRewatch => $composableBuilder(
      column: $table.isRewatch, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get newEpisodesSince => $composableBuilder(
      column: $table.newEpisodesSince,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastProgressAt => $composableBuilder(
      column: $table.lastProgressAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
      column: $table.finishedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get seasons => $composableBuilder(
      column: $table.seasons, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get watched => $composableBuilder(
      column: $table.watched, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get airedTotal => $composableBuilder(
      column: $table.airedTotal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nextEpisode => $composableBuilder(
      column: $table.nextEpisode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastAired => $composableBuilder(
      column: $table.lastAired, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get ranked => $composableBuilder(
      column: $table.ranked, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rankPosition => $composableBuilder(
      column: $table.rankPosition,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get score => $composableBuilder(
      column: $table.score, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));
}

class $$TrackingCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrackingCacheTable> {
  $$TrackingCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get posterPath => $composableBuilder(
      column: $table.posterPath, builder: (column) => column);

  GeneratedColumn<String> get backdropPath => $composableBuilder(
      column: $table.backdropPath, builder: (column) => column);

  GeneratedColumn<String> get titleStatus => $composableBuilder(
      column: $table.titleStatus, builder: (column) => column);

  GeneratedColumn<int> get runtimeMinutes => $composableBuilder(
      column: $table.runtimeMinutes, builder: (column) => column);

  GeneratedColumn<int> get lastSeason => $composableBuilder(
      column: $table.lastSeason, builder: (column) => column);

  GeneratedColumn<int> get lastEpisode => $composableBuilder(
      column: $table.lastEpisode, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<bool> get isRewatch =>
      $composableBuilder(column: $table.isRewatch, builder: (column) => column);

  GeneratedColumn<DateTime> get newEpisodesSince => $composableBuilder(
      column: $table.newEpisodesSince, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastProgressAt => $composableBuilder(
      column: $table.lastProgressAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
      column: $table.finishedAt, builder: (column) => column);

  GeneratedColumn<String> get seasons =>
      $composableBuilder(column: $table.seasons, builder: (column) => column);

  GeneratedColumn<int> get watched =>
      $composableBuilder(column: $table.watched, builder: (column) => column);

  GeneratedColumn<int> get airedTotal => $composableBuilder(
      column: $table.airedTotal, builder: (column) => column);

  GeneratedColumn<String> get nextEpisode => $composableBuilder(
      column: $table.nextEpisode, builder: (column) => column);

  GeneratedColumn<String> get lastAired =>
      $composableBuilder(column: $table.lastAired, builder: (column) => column);

  GeneratedColumn<bool> get ranked =>
      $composableBuilder(column: $table.ranked, builder: (column) => column);

  GeneratedColumn<int> get rankPosition => $composableBuilder(
      column: $table.rankPosition, builder: (column) => column);

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);
}

class $$TrackingCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TrackingCacheTable,
    TrackingCacheData,
    $$TrackingCacheTableFilterComposer,
    $$TrackingCacheTableOrderingComposer,
    $$TrackingCacheTableAnnotationComposer,
    $$TrackingCacheTableCreateCompanionBuilder,
    $$TrackingCacheTableUpdateCompanionBuilder,
    (
      TrackingCacheData,
      BaseReferences<_$AppDatabase, $TrackingCacheTable, TrackingCacheData>
    ),
    TrackingCacheData,
    PrefetchHooks Function()> {
  $$TrackingCacheTableTableManager(_$AppDatabase db, $TrackingCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackingCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackingCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackingCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> titleId = const Value.absent(),
            Value<String> mediaType = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> posterPath = const Value.absent(),
            Value<String?> backdropPath = const Value.absent(),
            Value<String?> titleStatus = const Value.absent(),
            Value<int?> runtimeMinutes = const Value.absent(),
            Value<int?> lastSeason = const Value.absent(),
            Value<int?> lastEpisode = const Value.absent(),
            Value<String> state = const Value.absent(),
            Value<bool> isRewatch = const Value.absent(),
            Value<DateTime?> newEpisodesSince = const Value.absent(),
            Value<DateTime> startedAt = const Value.absent(),
            Value<DateTime> lastProgressAt = const Value.absent(),
            Value<DateTime?> finishedAt = const Value.absent(),
            Value<String?> seasons = const Value.absent(),
            Value<int?> watched = const Value.absent(),
            Value<int?> airedTotal = const Value.absent(),
            Value<String?> nextEpisode = const Value.absent(),
            Value<String?> lastAired = const Value.absent(),
            Value<bool> ranked = const Value.absent(),
            Value<int?> rankPosition = const Value.absent(),
            Value<double?> score = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TrackingCacheCompanion(
            titleId: titleId,
            mediaType: mediaType,
            title: title,
            posterPath: posterPath,
            backdropPath: backdropPath,
            titleStatus: titleStatus,
            runtimeMinutes: runtimeMinutes,
            lastSeason: lastSeason,
            lastEpisode: lastEpisode,
            state: state,
            isRewatch: isRewatch,
            newEpisodesSince: newEpisodesSince,
            startedAt: startedAt,
            lastProgressAt: lastProgressAt,
            finishedAt: finishedAt,
            seasons: seasons,
            watched: watched,
            airedTotal: airedTotal,
            nextEpisode: nextEpisode,
            lastAired: lastAired,
            ranked: ranked,
            rankPosition: rankPosition,
            score: score,
            syncStatus: syncStatus,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int titleId,
            required String mediaType,
            required String title,
            Value<String?> posterPath = const Value.absent(),
            Value<String?> backdropPath = const Value.absent(),
            Value<String?> titleStatus = const Value.absent(),
            Value<int?> runtimeMinutes = const Value.absent(),
            Value<int?> lastSeason = const Value.absent(),
            Value<int?> lastEpisode = const Value.absent(),
            Value<String> state = const Value.absent(),
            Value<bool> isRewatch = const Value.absent(),
            Value<DateTime?> newEpisodesSince = const Value.absent(),
            Value<DateTime> startedAt = const Value.absent(),
            Value<DateTime> lastProgressAt = const Value.absent(),
            Value<DateTime?> finishedAt = const Value.absent(),
            Value<String?> seasons = const Value.absent(),
            Value<int?> watched = const Value.absent(),
            Value<int?> airedTotal = const Value.absent(),
            Value<String?> nextEpisode = const Value.absent(),
            Value<String?> lastAired = const Value.absent(),
            Value<bool> ranked = const Value.absent(),
            Value<int?> rankPosition = const Value.absent(),
            Value<double?> score = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TrackingCacheCompanion.insert(
            titleId: titleId,
            mediaType: mediaType,
            title: title,
            posterPath: posterPath,
            backdropPath: backdropPath,
            titleStatus: titleStatus,
            runtimeMinutes: runtimeMinutes,
            lastSeason: lastSeason,
            lastEpisode: lastEpisode,
            state: state,
            isRewatch: isRewatch,
            newEpisodesSince: newEpisodesSince,
            startedAt: startedAt,
            lastProgressAt: lastProgressAt,
            finishedAt: finishedAt,
            seasons: seasons,
            watched: watched,
            airedTotal: airedTotal,
            nextEpisode: nextEpisode,
            lastAired: lastAired,
            ranked: ranked,
            rankPosition: rankPosition,
            score: score,
            syncStatus: syncStatus,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$TrackingCacheTable, TrackingCacheData>(table),
                    BaseReferences<_$AppDatabase, $TrackingCacheTable,
                        TrackingCacheData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TrackingCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TrackingCacheTable,
    TrackingCacheData,
    $$TrackingCacheTableFilterComposer,
    $$TrackingCacheTableOrderingComposer,
    $$TrackingCacheTableAnnotationComposer,
    $$TrackingCacheTableCreateCompanionBuilder,
    $$TrackingCacheTableUpdateCompanionBuilder,
    (
      TrackingCacheData,
      BaseReferences<_$AppDatabase, $TrackingCacheTable, TrackingCacheData>
    ),
    TrackingCacheData,
    PrefetchHooks Function()>;
typedef $$EpisodeCacheTableCreateCompanionBuilder = EpisodeCacheCompanion
    Function({
  required int titleId,
  required int seasonNumber,
  required String json,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});
typedef $$EpisodeCacheTableUpdateCompanionBuilder = EpisodeCacheCompanion
    Function({
  Value<int> titleId,
  Value<int> seasonNumber,
  Value<String> json,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});

class $$EpisodeCacheTableFilterComposer
    extends Composer<_$AppDatabase, $EpisodeCacheTable> {
  $$EpisodeCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get titleId => $composableBuilder(
      column: $table.titleId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seasonNumber => $composableBuilder(
      column: $table.seasonNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnFilters(column));
}

class $$EpisodeCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $EpisodeCacheTable> {
  $$EpisodeCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get titleId => $composableBuilder(
      column: $table.titleId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seasonNumber => $composableBuilder(
      column: $table.seasonNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));
}

class $$EpisodeCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpisodeCacheTable> {
  $$EpisodeCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<int> get seasonNumber => $composableBuilder(
      column: $table.seasonNumber, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$EpisodeCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $EpisodeCacheTable,
    EpisodeCacheData,
    $$EpisodeCacheTableFilterComposer,
    $$EpisodeCacheTableOrderingComposer,
    $$EpisodeCacheTableAnnotationComposer,
    $$EpisodeCacheTableCreateCompanionBuilder,
    $$EpisodeCacheTableUpdateCompanionBuilder,
    (
      EpisodeCacheData,
      BaseReferences<_$AppDatabase, $EpisodeCacheTable, EpisodeCacheData>
    ),
    EpisodeCacheData,
    PrefetchHooks Function()> {
  $$EpisodeCacheTableTableManager(_$AppDatabase db, $EpisodeCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpisodeCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpisodeCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpisodeCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> titleId = const Value.absent(),
            Value<int> seasonNumber = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<DateTime> fetchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EpisodeCacheCompanion(
            titleId: titleId,
            seasonNumber: seasonNumber,
            json: json,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int titleId,
            required int seasonNumber,
            required String json,
            Value<DateTime> fetchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              EpisodeCacheCompanion.insert(
            titleId: titleId,
            seasonNumber: seasonNumber,
            json: json,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$EpisodeCacheTable, EpisodeCacheData>(table),
                    BaseReferences<_$AppDatabase, $EpisodeCacheTable,
                        EpisodeCacheData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$EpisodeCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $EpisodeCacheTable,
    EpisodeCacheData,
    $$EpisodeCacheTableFilterComposer,
    $$EpisodeCacheTableOrderingComposer,
    $$EpisodeCacheTableAnnotationComposer,
    $$EpisodeCacheTableCreateCompanionBuilder,
    $$EpisodeCacheTableUpdateCompanionBuilder,
    (
      EpisodeCacheData,
      BaseReferences<_$AppDatabase, $EpisodeCacheTable, EpisodeCacheData>
    ),
    EpisodeCacheData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedTitlesTableTableManager get cachedTitles =>
      $$CachedTitlesTableTableManager(_db, _db.cachedTitles);
  $$LocalRankingsTableTableManager get localRankings =>
      $$LocalRankingsTableTableManager(_db, _db.localRankings);
  $$PendingMutationsTableTableManager get pendingMutations =>
      $$PendingMutationsTableTableManager(_db, _db.pendingMutations);
  $$WatchlistCacheTableTableManager get watchlistCache =>
      $$WatchlistCacheTableTableManager(_db, _db.watchlistCache);
  $$GamificationCacheTableTableManager get gamificationCache =>
      $$GamificationCacheTableTableManager(_db, _db.gamificationCache);
  $$ExploreCacheTableTableManager get exploreCache =>
      $$ExploreCacheTableTableManager(_db, _db.exploreCache);
  $$TrackingCacheTableTableManager get trackingCache =>
      $$TrackingCacheTableTableManager(_db, _db.trackingCache);
  $$EpisodeCacheTableTableManager get episodeCache =>
      $$EpisodeCacheTableTableManager(_db, _db.episodeCache);
}
