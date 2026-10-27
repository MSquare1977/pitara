import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitara/models/category.dart';
import 'package:pitara/models/document.dart';
import 'package:pitara/models/member.dart';
import 'package:pitara/utils/document_search.dart';

void main() {
  const categories = [
    DocCategory(id: 'identity', name: 'Passport & visa', icon: Icons.badge_outlined),
    DocCategory(id: 'property', name: 'Property', icon: Icons.home_outlined),
    DocCategory(id: 'education', name: 'Education', icon: Icons.school_outlined),
  ];

  const members = [
    FamilyMember(id: 'm1', name: 'Mum', color: Colors.red),
    FamilyMember(id: 'm2', name: 'Dad', color: Colors.blue),
  ];

  final docs = <VaultDocument>[
    VaultDocument(
      id: 'd1',
      categoryId: 'identity',
      title: 'Passport (British)',
      subtitle: 'Expires Mar 2031',
      expiryDate: DateTime.now().add(const Duration(days: 1600)),
    ),
    VaultDocument(
      id: 'd2',
      categoryId: 'identity',
      title: 'OCI card',
      subtitle: 'Renew soon',
      expiryDate: DateTime.now().add(const Duration(days: 20)),
    ),
    VaultDocument(
      id: 'd3',
      categoryId: 'identity',
      title: 'US visitor visa',
      subtitle: 'Expires Jan 2029',
      expiryDate: DateTime.now().add(const Duration(days: 800)),
      memberId: 'm1',
    ),
    const VaultDocument(id: 'd4', categoryId: 'property', title: 'Flat deed - Pune'),
    const VaultDocument(id: 'd5', categoryId: 'education', title: 'Résumé'),
    VaultDocument(
      id: 'd6',
      categoryId: 'identity',
      title: 'Dad passport (Indian)',
      subtitle: 'Expires soon',
      expiryDate: DateTime.now().add(const Duration(days: 50)),
      memberId: 'm2',
    ),
  ];

  List<String> titles(String query) => searchDocuments(
        query: query,
        documents: docs,
        categories: categories,
        members: members,
      ).map((d) => d.title).toList();

  group('word by word', () {
    test('every word must match, in any order', () {
      expect(titles('british passport'), ['Passport (British)']);
      expect(titles('passport british'), ['Passport (British)']);
    });

    test('all words must match the same document', () {
      expect(titles('visa deed'), isEmpty);
    });

    test('a partly typed word matches', () {
      expect(titles('pass'), containsAll(['Passport (British)', 'Dad passport (Indian)']));
    });
  });

  group('capitals and accents', () {
    test('ignores capitals', () {
      expect(titles('RESUME'), ['Résumé']);
    });

    test('ignores accents in the document or the query', () {
      expect(titles('resume'), ['Résumé']);
      expect(titles('résumé'), ['Résumé']);
    });
  });

  group('typos', () {
    test('a small typo still finds the document', () {
      expect(titles('pasport'), containsAll(['Passport (British)', 'Dad passport (Indian)']));
    });

    test('short words never match fuzzily', () {
      expect(titles('ab'), isEmpty);
      expect(titles('a'), isEmpty);
    });

    test('nonsense finds nothing', () {
      expect(titles('zzzz'), isEmpty);
    });
  });

  group('category, person and expiry', () {
    test('matches the category name', () {
      expect(titles('property'), ['Flat deed - Pune']);
    });

    test('matches the person a document is tagged to', () {
      expect(titles('mum'), ['US visitor visa']);
      expect(titles('mum visa'), ['US visitor visa']);
    });

    test('"expiring" finds documents due within 90 days', () {
      expect(titles('expiring'), unorderedEquals(['OCI card', 'Dad passport (Indian)']));
    });

    test('expiry words combine with other words', () {
      // The OCI card sits in the "Passport & visa" category, so it matches
      // "passport" by category; the title match ranks first.
      expect(titles('passport expiring'), ['Dad passport (Indian)', 'OCI card']);
    });
  });

  group('empty input and ranking', () {
    test('empty or punctuation-only queries return nothing', () {
      expect(titles(''), isEmpty);
      expect(titles('   '), isEmpty);
      expect(titles(' ,, '), isEmpty);
    });

    test('a title match ranks above a category-only match', () {
      final result = titles('passport');
      expect(result.take(2).toSet(), {'Passport (British)', 'Dad passport (Indian)'});
      expect(result.sublist(2), unorderedEquals(['OCI card', 'US visitor visa']));
    });
  });
}