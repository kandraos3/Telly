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
          ..write('syncStatus: $syncStatus, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(showId, mediaType, title, posterPath,
      rankPosition, calculatedScore, bracket, syncStatus, updatedAt);
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
          ..write('syncStatus: $syncStatus, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OfflineDuelQueueTable extends OfflineDuelQueue
    with TableInfo<$OfflineDuelQueueTable, OfflineDuelQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineDuelQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _winnerTitleIdMeta =
      const VerificationMeta('winnerTitleId');
  @override
  late final GeneratedColumn<int> winnerTitleId = GeneratedColumn<int>(
      'winner_title_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _loserTitleIdMeta =
      const VerificationMeta('loserTitleId');
  @override
  late final GeneratedColumn<int> loserTitleId = GeneratedColumn<int>(
      'loser_title_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _mediaTypeMeta =
      const VerificationMeta('mediaType');
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
      'media_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _roundNumberMeta =
      const VerificationMeta('roundNumber');
  @override
  late final GeneratedColumn<int> roundNumber = GeneratedColumn<int>(
      'round_number', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
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
      defaultValue: const Constant('PENDING'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        winnerTitleId,
        loserTitleId,
        mediaType,
        roundNumber,
        createdAt,
        syncStatus
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_duel_queue';
  @override
  VerificationContext validateIntegrity(
      Insertable<OfflineDuelQueueData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('winner_title_id')) {
      context.handle(
          _winnerTitleIdMeta,
          winnerTitleId.isAcceptableOrUnknown(
              data['winner_title_id']!, _winnerTitleIdMeta));
    } else if (isInserting) {
      context.missing(_winnerTitleIdMeta);
    }
    if (data.containsKey('loser_title_id')) {
      context.handle(
          _loserTitleIdMeta,
          loserTitleId.isAcceptableOrUnknown(
              data['loser_title_id']!, _loserTitleIdMeta));
    } else if (isInserting) {
      context.missing(_loserTitleIdMeta);
    }
    if (data.containsKey('media_type')) {
      context.handle(_mediaTypeMeta,
          mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta));
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('round_number')) {
      context.handle(
          _roundNumberMeta,
          roundNumber.isAcceptableOrUnknown(
              data['round_number']!, _roundNumberMeta));
    } else if (isInserting) {
      context.missing(_roundNumberMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OfflineDuelQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineDuelQueueData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      winnerTitleId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}winner_title_id'])!,
      loserTitleId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}loser_title_id'])!,
      mediaType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}media_type'])!,
      roundNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}round_number'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
    );
  }

  @override
  $OfflineDuelQueueTable createAlias(String alias) {
    return $OfflineDuelQueueTable(attachedDatabase, alias);
  }
}

class OfflineDuelQueueData extends DataClass
    implements Insertable<OfflineDuelQueueData> {
  final String id;
  final int winnerTitleId;
  final int loserTitleId;
  final String mediaType;
  final int roundNumber;
  final DateTime createdAt;
  final String syncStatus;
  const OfflineDuelQueueData(
      {required this.id,
      required this.winnerTitleId,
      required this.loserTitleId,
      required this.mediaType,
      required this.roundNumber,
      required this.createdAt,
      required this.syncStatus});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['winner_title_id'] = Variable<int>(winnerTitleId);
    map['loser_title_id'] = Variable<int>(loserTitleId);
    map['media_type'] = Variable<String>(mediaType);
    map['round_number'] = Variable<int>(roundNumber);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  OfflineDuelQueueCompanion toCompanion(bool nullToAbsent) {
    return OfflineDuelQueueCompanion(
      id: Value(id),
      winnerTitleId: Value(winnerTitleId),
      loserTitleId: Value(loserTitleId),
      mediaType: Value(mediaType),
      roundNumber: Value(roundNumber),
      createdAt: Value(createdAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory OfflineDuelQueueData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineDuelQueueData(
      id: serializer.fromJson<String>(json['id']),
      winnerTitleId: serializer.fromJson<int>(json['winnerTitleId']),
      loserTitleId: serializer.fromJson<int>(json['loserTitleId']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      roundNumber: serializer.fromJson<int>(json['roundNumber']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'winnerTitleId': serializer.toJson<int>(winnerTitleId),
      'loserTitleId': serializer.toJson<int>(loserTitleId),
      'mediaType': serializer.toJson<String>(mediaType),
      'roundNumber': serializer.toJson<int>(roundNumber),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  OfflineDuelQueueData copyWith(
          {String? id,
          int? winnerTitleId,
          int? loserTitleId,
          String? mediaType,
          int? roundNumber,
          DateTime? createdAt,
          String? syncStatus}) =>
      OfflineDuelQueueData(
        id: id ?? this.id,
        winnerTitleId: winnerTitleId ?? this.winnerTitleId,
        loserTitleId: loserTitleId ?? this.loserTitleId,
        mediaType: mediaType ?? this.mediaType,
        roundNumber: roundNumber ?? this.roundNumber,
        createdAt: createdAt ?? this.createdAt,
        syncStatus: syncStatus ?? this.syncStatus,
      );
  OfflineDuelQueueData copyWithCompanion(OfflineDuelQueueCompanion data) {
    return OfflineDuelQueueData(
      id: data.id.present ? data.id.value : this.id,
      winnerTitleId: data.winnerTitleId.present
          ? data.winnerTitleId.value
          : this.winnerTitleId,
      loserTitleId: data.loserTitleId.present
          ? data.loserTitleId.value
          : this.loserTitleId,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      roundNumber:
          data.roundNumber.present ? data.roundNumber.value : this.roundNumber,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineDuelQueueData(')
          ..write('id: $id, ')
          ..write('winnerTitleId: $winnerTitleId, ')
          ..write('loserTitleId: $loserTitleId, ')
          ..write('mediaType: $mediaType, ')
          ..write('roundNumber: $roundNumber, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, winnerTitleId, loserTitleId, mediaType,
      roundNumber, createdAt, syncStatus);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineDuelQueueData &&
          other.id == this.id &&
          other.winnerTitleId == this.winnerTitleId &&
          other.loserTitleId == this.loserTitleId &&
          other.mediaType == this.mediaType &&
          other.roundNumber == this.roundNumber &&
          other.createdAt == this.createdAt &&
          other.syncStatus == this.syncStatus);
}

class OfflineDuelQueueCompanion extends UpdateCompanion<OfflineDuelQueueData> {
  final Value<String> id;
  final Value<int> winnerTitleId;
  final Value<int> loserTitleId;
  final Value<String> mediaType;
  final Value<int> roundNumber;
  final Value<DateTime> createdAt;
  final Value<String> syncStatus;
  final Value<int> rowid;
  const OfflineDuelQueueCompanion({
    this.id = const Value.absent(),
    this.winnerTitleId = const Value.absent(),
    this.loserTitleId = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.roundNumber = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OfflineDuelQueueCompanion.insert({
    required String id,
    required int winnerTitleId,
    required int loserTitleId,
    required String mediaType,
    required int roundNumber,
    this.createdAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        winnerTitleId = Value(winnerTitleId),
        loserTitleId = Value(loserTitleId),
        mediaType = Value(mediaType),
        roundNumber = Value(roundNumber);
  static Insertable<OfflineDuelQueueData> custom({
    Expression<String>? id,
    Expression<int>? winnerTitleId,
    Expression<int>? loserTitleId,
    Expression<String>? mediaType,
    Expression<int>? roundNumber,
    Expression<DateTime>? createdAt,
    Expression<String>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (winnerTitleId != null) 'winner_title_id': winnerTitleId,
      if (loserTitleId != null) 'loser_title_id': loserTitleId,
      if (mediaType != null) 'media_type': mediaType,
      if (roundNumber != null) 'round_number': roundNumber,
      if (createdAt != null) 'created_at': createdAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OfflineDuelQueueCompanion copyWith(
      {Value<String>? id,
      Value<int>? winnerTitleId,
      Value<int>? loserTitleId,
      Value<String>? mediaType,
      Value<int>? roundNumber,
      Value<DateTime>? createdAt,
      Value<String>? syncStatus,
      Value<int>? rowid}) {
    return OfflineDuelQueueCompanion(
      id: id ?? this.id,
      winnerTitleId: winnerTitleId ?? this.winnerTitleId,
      loserTitleId: loserTitleId ?? this.loserTitleId,
      mediaType: mediaType ?? this.mediaType,
      roundNumber: roundNumber ?? this.roundNumber,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (winnerTitleId.present) {
      map['winner_title_id'] = Variable<int>(winnerTitleId.value);
    }
    if (loserTitleId.present) {
      map['loser_title_id'] = Variable<int>(loserTitleId.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (roundNumber.present) {
      map['round_number'] = Variable<int>(roundNumber.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('OfflineDuelQueueCompanion(')
          ..write('id: $id, ')
          ..write('winnerTitleId: $winnerTitleId, ')
          ..write('loserTitleId: $loserTitleId, ')
          ..write('mediaType: $mediaType, ')
          ..write('roundNumber: $roundNumber, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedTitlesTable cachedTitles = $CachedTitlesTable(this);
  late final $LocalRankingsTable localRankings = $LocalRankingsTable(this);
  late final $OfflineDuelQueueTable offlineDuelQueue =
      $OfflineDuelQueueTable(this);
  late final $WatchlistCacheTable watchlistCache = $WatchlistCacheTable(this);
  late final LocalRankingDao localRankingDao =
      LocalRankingDao(this as AppDatabase);
  late final LocalTitleDao localTitleDao = LocalTitleDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [cachedTitles, localRankings, offlineDuelQueue, watchlistCache];
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
typedef $$OfflineDuelQueueTableCreateCompanionBuilder
    = OfflineDuelQueueCompanion Function({
  required String id,
  required int winnerTitleId,
  required int loserTitleId,
  required String mediaType,
  required int roundNumber,
  Value<DateTime> createdAt,
  Value<String> syncStatus,
  Value<int> rowid,
});
typedef $$OfflineDuelQueueTableUpdateCompanionBuilder
    = OfflineDuelQueueCompanion Function({
  Value<String> id,
  Value<int> winnerTitleId,
  Value<int> loserTitleId,
  Value<String> mediaType,
  Value<int> roundNumber,
  Value<DateTime> createdAt,
  Value<String> syncStatus,
  Value<int> rowid,
});

class $$OfflineDuelQueueTableFilterComposer
    extends Composer<_$AppDatabase, $OfflineDuelQueueTable> {
  $$OfflineDuelQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get winnerTitleId => $composableBuilder(
      column: $table.winnerTitleId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get loserTitleId => $composableBuilder(
      column: $table.loserTitleId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get roundNumber => $composableBuilder(
      column: $table.roundNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));
}

class $$OfflineDuelQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $OfflineDuelQueueTable> {
  $$OfflineDuelQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get winnerTitleId => $composableBuilder(
      column: $table.winnerTitleId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get loserTitleId => $composableBuilder(
      column: $table.loserTitleId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mediaType => $composableBuilder(
      column: $table.mediaType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get roundNumber => $composableBuilder(
      column: $table.roundNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));
}

class $$OfflineDuelQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfflineDuelQueueTable> {
  $$OfflineDuelQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get winnerTitleId => $composableBuilder(
      column: $table.winnerTitleId, builder: (column) => column);

  GeneratedColumn<int> get loserTitleId => $composableBuilder(
      column: $table.loserTitleId, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<int> get roundNumber => $composableBuilder(
      column: $table.roundNumber, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);
}

class $$OfflineDuelQueueTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OfflineDuelQueueTable,
    OfflineDuelQueueData,
    $$OfflineDuelQueueTableFilterComposer,
    $$OfflineDuelQueueTableOrderingComposer,
    $$OfflineDuelQueueTableAnnotationComposer,
    $$OfflineDuelQueueTableCreateCompanionBuilder,
    $$OfflineDuelQueueTableUpdateCompanionBuilder,
    (
      OfflineDuelQueueData,
      BaseReferences<_$AppDatabase, $OfflineDuelQueueTable,
          OfflineDuelQueueData>
    ),
    OfflineDuelQueueData,
    PrefetchHooks Function()> {
  $$OfflineDuelQueueTableTableManager(
      _$AppDatabase db, $OfflineDuelQueueTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineDuelQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfflineDuelQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfflineDuelQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int> winnerTitleId = const Value.absent(),
            Value<int> loserTitleId = const Value.absent(),
            Value<String> mediaType = const Value.absent(),
            Value<int> roundNumber = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OfflineDuelQueueCompanion(
            id: id,
            winnerTitleId: winnerTitleId,
            loserTitleId: loserTitleId,
            mediaType: mediaType,
            roundNumber: roundNumber,
            createdAt: createdAt,
            syncStatus: syncStatus,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required int winnerTitleId,
            required int loserTitleId,
            required String mediaType,
            required int roundNumber,
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OfflineDuelQueueCompanion.insert(
            id: id,
            winnerTitleId: winnerTitleId,
            loserTitleId: loserTitleId,
            mediaType: mediaType,
            roundNumber: roundNumber,
            createdAt: createdAt,
            syncStatus: syncStatus,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$OfflineDuelQueueTable, OfflineDuelQueueData>(
                        table),
                    BaseReferences<_$AppDatabase, $OfflineDuelQueueTable,
                        OfflineDuelQueueData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OfflineDuelQueueTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OfflineDuelQueueTable,
    OfflineDuelQueueData,
    $$OfflineDuelQueueTableFilterComposer,
    $$OfflineDuelQueueTableOrderingComposer,
    $$OfflineDuelQueueTableAnnotationComposer,
    $$OfflineDuelQueueTableCreateCompanionBuilder,
    $$OfflineDuelQueueTableUpdateCompanionBuilder,
    (
      OfflineDuelQueueData,
      BaseReferences<_$AppDatabase, $OfflineDuelQueueTable,
          OfflineDuelQueueData>
    ),
    OfflineDuelQueueData,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedTitlesTableTableManager get cachedTitles =>
      $$CachedTitlesTableTableManager(_db, _db.cachedTitles);
  $$LocalRankingsTableTableManager get localRankings =>
      $$LocalRankingsTableTableManager(_db, _db.localRankings);
  $$OfflineDuelQueueTableTableManager get offlineDuelQueue =>
      $$OfflineDuelQueueTableTableManager(_db, _db.offlineDuelQueue);
  $$WatchlistCacheTableTableManager get watchlistCache =>
      $$WatchlistCacheTableTableManager(_db, _db.watchlistCache);
}
