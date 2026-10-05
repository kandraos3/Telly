import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/custom_list_models.dart';

abstract interface class CustomListRepository {
  Stream<List<CustomList>> watchUserLists();
  Future<List<CustomList>> getUserLists();
  Stream<List<CustomList>> watchSharedLists();
  Future<List<CustomList>> getSharedLists();
  Future<CustomList?> getListById(String listId);

  Future<CustomList> createList({
    required String title,
    String? description,
    bool isPrivate = false,
  });

  Future<void> updateList(CustomList list);
  Future<void> deleteList(String listId);

  Future<void> addItem({
    required String listId,
    required int showId,
    required String title,
    required String mediaType,
    String? posterPath,
  });

  Future<void> removeItem({
    required String listId,
    required String itemId,
  });

  Future<void> reorderItems({
    required String listId,
    required int oldIndex,
    required int newIndex,
  });

  Future<void> saveSharedList(CustomList list);
}

class InMemoryCustomListRepository implements CustomListRepository {
  InMemoryCustomListRepository() {
    _initSeedData();
  }

  final _uuid = const Uuid();
  final _userListsStream = StreamController<List<CustomList>>.broadcast();
  final _sharedListsStream = StreamController<List<CustomList>>.broadcast();

  final List<CustomList> _userLists = [];
  final List<CustomList> _sharedLists = [];

  void _initSeedData() {
    final now = DateTime.now();
    _userLists.addAll([
      CustomList(
        id: 'list-criterion-01',
        title: 'Criterion Must-Sees',
        description: 'Masterpieces essential for cinema lovers',
        isPrivate: false,
        ownerHandle: '@me',
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 2)),
        collaborators: const ['@maya'],
        items: [
          CustomListItem(
            id: 'item-1',
            listId: 'list-criterion-01',
            showId: 201,
            title: 'Parasite',
            mediaType: 'movie',
            addedAt: now.subtract(const Duration(days: 5)),
            order: 0,
          ),
          CustomListItem(
            id: 'item-2',
            listId: 'list-criterion-01',
            showId: 202,
            title: 'Spirited Away',
            mediaType: 'movie',
            addedAt: now.subtract(const Duration(days: 4)),
            order: 1,
          ),
        ],
      ),
      CustomList(
        id: 'list-spooky-02',
        title: 'Spooky Season Marathon',
        description: 'Autumn psychological horror and thrillers',
        isPrivate: true,
        ownerHandle: '@me',
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 1)),
        collaborators: const [],
        items: [
          CustomListItem(
            id: 'item-3',
            listId: 'list-spooky-02',
            showId: 103,
            title: 'Fargo',
            mediaType: 'tv',
            addedAt: now.subtract(const Duration(days: 2)),
            order: 0,
          ),
        ],
      ),
    ]);

    _sharedLists.addAll([
      CustomList(
        id: 'list-shared-01',
        title: 'A24 Masterclass',
        description: 'Every great indie release from A24 studio',
        isPrivate: false,
        ownerHandle: '@maya',
        createdAt: now.subtract(const Duration(days: 14)),
        updatedAt: now.subtract(const Duration(days: 3)),
        collaborators: const ['@maya', '@alex'],
        items: [
          CustomListItem(
            id: 'item-4',
            listId: 'list-shared-01',
            showId: 301,
            title: 'Everything Everywhere All at Once',
            mediaType: 'movie',
            addedAt: now.subtract(const Duration(days: 12)),
            order: 0,
          ),
          CustomListItem(
            id: 'item-5',
            listId: 'list-shared-01',
            showId: 302,
            title: 'Past Lives',
            mediaType: 'movie',
            addedAt: now.subtract(const Duration(days: 8)),
            order: 1,
          ),
        ],
      ),
      CustomList(
        id: 'list-shared-02',
        title: 'Prestige TV Golden Age',
        description: 'Top-tier serialized television that redefined the medium',
        isPrivate: false,
        ownerHandle: '@alex',
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now.subtract(const Duration(days: 4)),
        collaborators: const ['@alex'],
        items: [
          CustomListItem(
            id: 'item-6',
            listId: 'list-shared-02',
            showId: 101,
            title: 'Slow Horses',
            mediaType: 'tv',
            addedAt: now.subtract(const Duration(days: 10)),
            order: 0,
          ),
          CustomListItem(
            id: 'item-7',
            listId: 'list-shared-02',
            showId: 401,
            title: 'Succession',
            mediaType: 'tv',
            addedAt: now.subtract(const Duration(days: 9)),
            order: 1,
          ),
        ],
      ),
    ]);
  }

  void _notifyUser() {
    _userListsStream.add(List.unmodifiable(_userLists));
  }

  @override
  Stream<List<CustomList>> watchUserLists() {
    return _userListsStream.stream;
  }

  @override
  Future<List<CustomList>> getUserLists() async {
    return List.unmodifiable(_userLists);
  }

  @override
  Stream<List<CustomList>> watchSharedLists() {
    return _sharedListsStream.stream;
  }

  @override
  Future<List<CustomList>> getSharedLists() async {
    return List.unmodifiable(_sharedLists);
  }

  @override
  Future<CustomList?> getListById(String listId) async {
    for (final l in _userLists) {
      if (l.id == listId) return l;
    }
    for (final l in _sharedLists) {
      if (l.id == listId) return l;
    }
    return null;
  }

  @override
  Future<CustomList> createList({
    required String title,
    String? description,
    bool isPrivate = false,
  }) async {
    final now = DateTime.now();
    final newList = CustomList(
      id: 'list-${_uuid.v4().substring(0, 8)}',
      title: title,
      description: description,
      isPrivate: isPrivate,
      ownerHandle: '@me',
      createdAt: now,
      updatedAt: now,
      collaborators: const [],
      items: const [],
    );
    _userLists.insert(0, newList);
    _notifyUser();
    return newList;
  }

  @override
  Future<void> updateList(CustomList list) async {
    final index = _userLists.indexWhere((l) => l.id == list.id);
    if (index != -1) {
      _userLists[index] = list.copyWith(updatedAt: DateTime.now());
      _notifyUser();
    }
  }

  @override
  Future<void> deleteList(String listId) async {
    _userLists.removeWhere((l) => l.id == listId);
    _notifyUser();
  }

  @override
  Future<void> addItem({
    required String listId,
    required int showId,
    required String title,
    required String mediaType,
    String? posterPath,
  }) async {
    final index = _userLists.indexWhere((l) => l.id == listId);
    if (index != -1) {
      final list = _userLists[index];
      final newItem = CustomListItem(
        id: 'item-${_uuid.v4().substring(0, 8)}',
        listId: listId,
        showId: showId,
        title: title,
        mediaType: mediaType,
        posterPath: posterPath,
        addedAt: DateTime.now(),
        order: list.items.length,
      );
      final updatedItems = [...list.items, newItem];
      _userLists[index] = list.copyWith(items: updatedItems, updatedAt: DateTime.now());
      _notifyUser();
    }
  }

  @override
  Future<void> removeItem({
    required String listId,
    required String itemId,
  }) async {
    final index = _userLists.indexWhere((l) => l.id == listId);
    if (index != -1) {
      final list = _userLists[index];
      final updatedItems = list.items.where((i) => i.id != itemId).toList();
      _userLists[index] = list.copyWith(items: updatedItems, updatedAt: DateTime.now());
      _notifyUser();
    }
  }

  @override
  Future<void> reorderItems({
    required String listId,
    required int oldIndex,
    required int newIndex,
  }) async {
    final index = _userLists.indexWhere((l) => l.id == listId);
    if (index != -1) {
      final list = _userLists[index];
      final items = List<CustomListItem>.from(list.items);
      var adjustedNewIndex = newIndex;
      if (oldIndex < adjustedNewIndex) {
        adjustedNewIndex -= 1;
      }
      final item = items.removeAt(oldIndex);
      items.insert(adjustedNewIndex, item);
      // Re-assign order indices
      final reordered = [
        for (var i = 0; i < items.length; i++) items[i].copyWith(order: i),
      ];
      _userLists[index] = list.copyWith(items: reordered, updatedAt: DateTime.now());
      _notifyUser();
    }
  }

  @override
  Future<void> saveSharedList(CustomList list) async {
    final alreadySaved = _userLists.any((l) => l.id == list.id);
    if (!alreadySaved) {
      final clonedList = list.copyWith(
        id: 'saved-${list.id}',
        title: '${list.title} (Saved)',
        ownerHandle: '@me',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _userLists.insert(0, clonedList);
      _notifyUser();
    }
  }
}

final customListRepositoryProvider = Provider<CustomListRepository>((ref) {
  return InMemoryCustomListRepository();
});

class UserCustomListsNotifier extends AsyncNotifier<List<CustomList>> {
  @override
  Future<List<CustomList>> build() async {
    final repo = ref.watch(customListRepositoryProvider);
    final sub = repo.watchUserLists().listen((lists) {
      state = AsyncData(lists);
    });
    ref.onDispose(sub.cancel);
    return repo.getUserLists();
  }

  Future<CustomList> createList({
    required String title,
    String? description,
    bool isPrivate = false,
  }) async {
    final repo = ref.read(customListRepositoryProvider);
    final list = await repo.createList(
      title: title,
      description: description,
      isPrivate: isPrivate,
    );
    state = AsyncData(await repo.getUserLists());
    return list;
  }

  Future<void> deleteList(String listId) async {
    final repo = ref.read(customListRepositoryProvider);
    await repo.deleteList(listId);
    state = AsyncData(await repo.getUserLists());
  }

  Future<void> removeItem(String listId, String itemId) async {
    final repo = ref.read(customListRepositoryProvider);
    await repo.removeItem(listId: listId, itemId: itemId);
    state = AsyncData(await repo.getUserLists());
  }

  Future<void> reorderItems(String listId, int oldIndex, int newIndex) async {
    final repo = ref.read(customListRepositoryProvider);
    await repo.reorderItems(listId: listId, oldIndex: oldIndex, newIndex: newIndex);
    state = AsyncData(await repo.getUserLists());
  }

  Future<void> saveSharedList(CustomList list) async {
    final repo = ref.read(customListRepositoryProvider);
    await repo.saveSharedList(list);
    state = AsyncData(await repo.getUserLists());
  }
}

final userCustomListsProvider =
    AsyncNotifierProvider<UserCustomListsNotifier, List<CustomList>>(UserCustomListsNotifier.new);

class SharedCustomListsNotifier extends AsyncNotifier<List<CustomList>> {
  @override
  Future<List<CustomList>> build() async {
    final repo = ref.watch(customListRepositoryProvider);
    final sub = repo.watchSharedLists().listen((lists) {
      state = AsyncData(lists);
    });
    ref.onDispose(sub.cancel);
    return repo.getSharedLists();
  }
}

final sharedCustomListsProvider =
    AsyncNotifierProvider<SharedCustomListsNotifier, List<CustomList>>(SharedCustomListsNotifier.new);
