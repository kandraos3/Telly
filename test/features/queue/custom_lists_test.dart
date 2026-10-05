import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/features/queue/data/custom_list_repository.dart';
import 'package:telly_app/features/queue/domain/custom_list_models.dart';
import 'package:telly_app/features/queue/presentation/screens/custom_list_detail_screen.dart';
import 'package:telly_app/features/queue/presentation/screens/smart_queue_screen.dart';

void main() {
  group('FE-LISTS-01: CustomListRepository Unit Tests', () {
    late InMemoryCustomListRepository repo;

    setUp(() {
      repo = InMemoryCustomListRepository();
    });

    test('creates custom list with public/private setting', () async {
      final list = await repo.createList(
        title: 'Horror Classics',
        description: 'Spooky season picks',
        isPrivate: true,
      );

      expect(list.title, 'Horror Classics');
      expect(list.isPrivate, isTrue);
      expect(list.ownerHandle, '@me');

      final userLists = await repo.getUserLists();
      expect(userLists.any((l) => l.title == 'Horror Classics'), isTrue);
    });

    test('adds, reorders, and removes items in custom list', () async {
      final list = await repo.createList(
        title: 'Cinema 101',
        isPrivate: false,
      );

      await repo.addItem(
        listId: list.id,
        showId: 101,
        title: 'Movie A',
        mediaType: 'movie',
      );
      await repo.addItem(
        listId: list.id,
        showId: 102,
        title: 'Movie B',
        mediaType: 'movie',
      );

      var updated = await repo.getListById(list.id);
      expect(updated?.items.length, 2);
      expect(updated?.items[0].title, 'Movie A');
      expect(updated?.items[1].title, 'Movie B');

      // Reorder items: move index 0 to after index 1
      await repo.reorderItems(listId: list.id, oldIndex: 0, newIndex: 2);
      updated = await repo.getListById(list.id);
      expect(updated?.items[0].title, 'Movie B');
      expect(updated?.items[1].title, 'Movie A');

      // Remove an item
      final itemToRemove = updated!.items.first;
      await repo.removeItem(listId: list.id, itemId: itemToRemove.id);
      updated = await repo.getListById(list.id);
      expect(updated?.items.length, 1);
      expect(updated?.items[0].title, 'Movie A');
    });

    test('saves a shared friends list to user lists', () async {
      final sharedLists = await repo.getSharedLists();
      expect(sharedLists.isNotEmpty, isTrue);
      final friendList = sharedLists.first;

      await repo.saveSharedList(friendList);
      final userLists = await repo.getUserLists();
      expect(userLists.any((l) => l.id == 'saved-${friendList.id}'), isTrue);
    });
  });

  group('FE-LISTS-01: SmartQueueScreen & Custom Lists Hub Widget Tests', () {
    Widget createHubWidget({
      QueueHubMode initialMode = QueueHubMode.myLists,
      List<CustomList>? customLists,
      List<CustomList>? sharedLists,
    }) {
      return ProviderScope(
        child: MaterialApp(
          theme: TellyTheme.dark,
          home: SmartQueueScreen(
            initialMode: initialMode,
            testCustomLists: customLists,
            testSharedLists: sharedLists,
          ),
        ),
      );
    }

    testWidgets('renders hub tabs and switches to My Lists view', (tester) async {
      await tester.pumpWidget(createHubWidget(initialMode: QueueHubMode.watchlist));
      await tester.pumpAndSettle();

      expect(find.text('Watchlist'), findsOneWidget);
      expect(find.text('My Lists'), findsOneWidget);
      expect(find.text('Friends\' Lists'), findsOneWidget);

      // Tap "My Lists" pill
      await tester.tap(find.text('My Lists'));
      await tester.pumpAndSettle();

      expect(find.text('MY CURATED LISTS (2)'), findsOneWidget);
      expect(find.text('Criterion Must-Sees'), findsOneWidget);
      expect(find.text('Spooky Season Marathon'), findsOneWidget);
      expect(find.text('PUBLIC'), findsWidgets);
      expect(find.text('PRIVATE'), findsWidgets);
    });

    testWidgets('header actions follow the hub mode (FE-HEADER-01)', (tester) async {
      await tester.pumpWidget(createHubWidget(initialMode: QueueHubMode.watchlist));
      await tester.pumpAndSettle();
      expect(find.text('Queue'), findsOneWidget);
      expect(find.byKey(const Key('queue_sort_button')), findsOneWidget);
      expect(find.byKey(const Key('create_new_list_button')), findsNothing);

      await tester.tap(find.text('My Lists'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('queue_sort_button')), findsNothing);
      expect(find.byKey(const Key('create_new_list_button')), findsOneWidget);

      await tester.tap(find.text('Friends\' Lists'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('queue_sort_button')), findsNothing);
      expect(find.byKey(const Key('create_new_list_button')), findsNothing);
    });

    testWidgets('creates new named custom list with private toggle', (tester) async {
      await tester.pumpWidget(createHubWidget(initialMode: QueueHubMode.myLists));
      await tester.pumpAndSettle();

      // Tap "New List" button
      await tester.tap(find.byKey(const Key('create_new_list_button')));
      await tester.pumpAndSettle();

      expect(find.text('Create Custom List'), findsOneWidget);

      // Fill in title
      await tester.enterText(
        find.byKey(const Key('create_list_title_field')),
        'Cyberpunk Essentials',
      );
      // Fill in description
      await tester.enterText(
        find.byKey(const Key('create_list_desc_field')),
        'Dystopian neon visions',
      );
      // Toggle private switch
      await tester.tap(find.byKey(const Key('create_list_private_switch')));
      await tester.pumpAndSettle();

      // Submit creation
      await tester.tap(find.byKey(const Key('create_list_submit_button')));
      await tester.pumpAndSettle();

      // Verify list appears in list
      expect(find.text('Cyberpunk Essentials'), findsOneWidget);
      expect(find.text('Dystopian neon visions'), findsOneWidget);
    });

    testWidgets('switches to Friends Lists and saves friend list', (tester) async {
      await tester.pumpWidget(createHubWidget(initialMode: QueueHubMode.sharedLists));
      await tester.pumpAndSettle();

      expect(find.text('SHARED BY FRIENDS (2)'), findsOneWidget);
      expect(find.text('A24 Masterclass'), findsOneWidget);
      expect(find.text('Prestige TV Golden Age'), findsOneWidget);

      // Tap save list on the first friend list
      final saveButtons = find.byTooltip('Save to My Lists');
      expect(saveButtons, findsWidgets);
      await tester.tap(saveButtons.first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Saved "A24 Masterclass" to your lists!'), findsOneWidget);
    });
  });

  group('FE-LISTS-01: CustomListDetailScreen Widget Tests', () {
    final testList = CustomList(
      id: 'test-list-42',
      title: 'Studio Ghibli Wonders',
      description: 'Hand-drawn animation epics',
      isPrivate: false,
      ownerHandle: '@me',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      collaborators: const ['@maya'],
      items: [
        CustomListItem(
          id: 'ghibli-1',
          listId: 'test-list-42',
          showId: 202,
          title: 'Spirited Away',
          mediaType: 'movie',
          addedAt: DateTime.now(),
          order: 0,
        ),
        CustomListItem(
          id: 'ghibli-2',
          listId: 'test-list-42',
          showId: 203,
          title: 'Princess Mononoke',
          mediaType: 'movie',
          addedAt: DateTime.now(),
          order: 1,
        ),
      ],
    );

    Widget createDetailWidget(CustomList list) {
      return ProviderScope(
        child: MaterialApp(
          theme: TellyTheme.dark,
          home: CustomListDetailScreen(
            listId: list.id,
            initialList: list,
          ),
        ),
      );
    }

    testWidgets('renders list details, badges, and items', (tester) async {
      await tester.pumpWidget(createDetailWidget(testList));
      await tester.pumpAndSettle();

      expect(find.text('STUDIO GHIBLI WONDERS'), findsOneWidget);
      expect(find.text('Hand-drawn animation epics'), findsOneWidget);
      expect(find.text('PUBLIC'), findsOneWidget);
      expect(find.text('@maya'), findsOneWidget);
      expect(find.text('TITLES (2)'), findsOneWidget);
      expect(find.text('Spirited Away'), findsOneWidget);
      expect(find.text('Princess Mononoke'), findsOneWidget);
    });

    testWidgets('shares list via deep link and copies to clipboard', (tester) async {
      // Mock clipboard handler
      final log = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
        log.add(methodCall);
        return null;
      });

      await tester.pumpWidget(createDetailWidget(testList));
      await tester.pumpAndSettle();

      // Tap share button
      await tester.tap(find.byTooltip('Share List'));
      await tester.pumpAndSettle();

      expect(find.textContaining('https://telly.app/lists/test-list-42'), findsOneWidget);
    });

    testWidgets('removes an item from the list', (tester) async {
      await tester.pumpWidget(createDetailWidget(testList));
      await tester.pumpAndSettle();

      expect(find.text('Spirited Away'), findsOneWidget);

      final removeButtons = find.byTooltip('Remove from List');
      expect(removeButtons, findsNWidgets(2));

      await tester.tap(removeButtons.first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Removed "Spirited Away" from list'), findsOneWidget);
    });
  });
}
