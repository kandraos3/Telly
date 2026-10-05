/// Domain models for Custom User Lists and Shared Friend Lists.
/// Defined in `FE-LISTS-01` & `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §13.
library custom_list_models;

class CustomListItem {
  final String id;
  final String listId;
  final int showId;
  final String title;
  final String mediaType; // 'movie' or 'tv'
  final String? posterPath;
  final DateTime addedAt;
  final int order;
  final String? addedByHandle;

  const CustomListItem({
    required this.id,
    required this.listId,
    required this.showId,
    required this.title,
    required this.mediaType,
    this.posterPath,
    required this.addedAt,
    this.order = 0,
    this.addedByHandle,
  });

  CustomListItem copyWith({
    String? id,
    String? listId,
    int? showId,
    String? title,
    String? mediaType,
    String? posterPath,
    DateTime? addedAt,
    int? order,
    String? addedByHandle,
  }) {
    return CustomListItem(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      showId: showId ?? this.showId,
      title: title ?? this.title,
      mediaType: mediaType ?? this.mediaType,
      posterPath: posterPath ?? this.posterPath,
      addedAt: addedAt ?? this.addedAt,
      order: order ?? this.order,
      addedByHandle: addedByHandle ?? this.addedByHandle,
    );
  }
}

class CustomList {
  final String id;
  final String title;
  final String? description;
  final bool isPrivate;
  final String ownerHandle;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> collaborators;
  final List<CustomListItem> items;

  const CustomList({
    required this.id,
    required this.title,
    this.description,
    this.isPrivate = false,
    required this.ownerHandle,
    required this.createdAt,
    required this.updatedAt,
    this.collaborators = const [],
    this.items = const [],
  });

  int get movieCount => items.where((i) => i.mediaType == 'movie').length;
  int get seriesCount => items.where((i) => i.mediaType == 'tv').length;
  int get totalCount => items.length;

  bool isOwner(String currentHandle) =>
      ownerHandle.replaceAll('@', '').toLowerCase() == currentHandle.replaceAll('@', '').toLowerCase();

  CustomList copyWith({
    String? id,
    String? title,
    String? description,
    bool? isPrivate,
    String? ownerHandle,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? collaborators,
    List<CustomListItem>? items,
  }) {
    return CustomList(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isPrivate: isPrivate ?? this.isPrivate,
      ownerHandle: ownerHandle ?? this.ownerHandle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      collaborators: collaborators ?? this.collaborators,
      items: items ?? this.items,
    );
  }
}
