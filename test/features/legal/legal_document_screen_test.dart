import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/features/legal/domain/legal_markdown.dart';
import 'package:telly_app/features/legal/presentation/screens/legal_document_screen.dart';

void main() {
  group('FE-AUTH-04: LegalDocumentScreen', () {
    for (final doc in LegalDocument.values) {
      testWidgets('renders the bundled ${doc.title}', (tester) async {
        await tester.pumpWidget(MaterialApp(home: LegalDocumentScreen(document: doc)));
        await tester.pumpAndSettle();

        expect(find.text(doc.title), findsOneWidget); // app bar
        expect(find.textContaining('Last Updated', findRichText: true), findsOneWidget);
        expect(find.textContaining('Telly', findRichText: true), findsWidgets);
      });
    }

    testWidgets('shows an error state when the asset is missing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: LegalDocumentScreen(document: LegalDocument.terms, bundle: _EmptyBundle())),
      );
      await tester.pumpAndSettle();
      expect(find.text('This document could not be loaded.'), findsOneWidget);
    });
  });
}

class _EmptyBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => Future.error(FlutterError('missing $key'));
}
