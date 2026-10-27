import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitara/models/category.dart';
import 'package:pitara/models/document.dart';
import 'package:pitara/models/planned_item.dart';
import 'package:pitara/utils/checklist_rows.dart';

void main() {
  const categories = [
    DocCategory(id: 'identity', name: 'Passport & visa', icon: Icons.badge_outlined),
    DocCategory(id: 'property', name: 'Property', icon: Icons.home_outlined),
  ];
  const passport = VaultDocument(id: 'd1', categoryId: 'identity', title: 'British passport');
  const deed = VaultDocument(id: 'd2', categoryId: 'property', title: 'Flat deed');
  final today = DateTime(2026, 10, 18);

  List<ChecklistRow> build({
    List<VaultDocument> docs = const [passport, deed],
    List<DocCategory> cats = categories,
    List<PlannedItem> planned = const [],
  }) =>
      buildChecklistRows(documents: docs, categories: cats, plannedItems: planned, now: today);

  test('documents appear automatically as Added', () {
    final rows = build();
    expect(rows.length, 2);
    expect(rows.every((r) => r.status == ChecklistStatus.added), isTrue);
  });

  test('a placeholder shows as To add and sorts first', () {
    final rows = build(planned: const [
      PlannedItem(id: 'p1', name: 'Degree certificate', categoryId: 'property'),
    ]);
    expect(rows.length, 3);
    expect(rows.first.title, 'Degree certificate');
    expect(rows.first.status, ChecklistStatus.toAdd);
  });

  test('a placeholder linked to a document shows once, with the document title', () {
    final rows = build(planned: const [
      PlannedItem(id: 'p1', name: 'Passport', categoryId: 'identity', linkedDocumentId: 'd1'),
    ]);
    expect(rows.map((r) => r.title).toList(), ['British passport', 'Flat deed']);
    expect(rows.every((r) => r.status == ChecklistStatus.added), isTrue);
  });

  test('deleting the linked document sends the row back to To add', () {
    final rows = build(
      docs: const [deed],
      planned: const [
        PlannedItem(id: 'p1', name: 'Passport', categoryId: 'identity', linkedDocumentId: 'd1'),
      ],
    );
    final passportRow = rows.firstWhere((r) => r.title == 'Passport');
    expect(passportRow.status, ChecklistStatus.toAdd);
    expect(rows.length, 2);
  });

  test('a deleted folder shows "No folder"', () {
    final rows = build(
      cats: const [
        DocCategory(id: 'property', name: 'Property', icon: Icons.home_outlined),
      ],
      planned: const [PlannedItem(id: 'p1', name: 'Visa', categoryId: 'identity')],
    );
    expect(rows.firstWhere((r) => r.title == 'Visa').folderName, noFolderLabel);
  });

  test('To-add rows: overdue first, then soonest due date, undated last', () {
    final rows = build(planned: [
      PlannedItem(
          id: 'p1', name: 'Late', categoryId: 'identity', dueDate: today.subtract(const Duration(days: 1))),
      PlannedItem(
          id: 'p2', name: 'Soon', categoryId: 'identity', dueDate: today.add(const Duration(days: 5))),
      const PlannedItem(id: 'p3', name: 'NoDate', categoryId: 'identity'),
      PlannedItem(id: 'p4', name: 'Today', categoryId: 'identity', dueDate: today),
    ]);
    final toAdd = rows.where((r) => r.status == ChecklistStatus.toAdd).toList();
    expect(toAdd.map((r) => r.title).toList(), ['Late', 'Today', 'Soon', 'NoDate']);
    expect(toAdd.map((r) => r.overdue).toList(), [true, false, false, false]);
  });

  test('two placeholders on one document: only the first attaches', () {
    final rows = build(planned: const [
      PlannedItem(id: 'p1', name: 'A', categoryId: 'identity', linkedDocumentId: 'd1'),
      PlannedItem(id: 'p2', name: 'B', categoryId: 'identity', linkedDocumentId: 'd1'),
    ]);
    expect(rows.where((r) => r.status == ChecklistStatus.added).length, 2);
    expect(rows.firstWhere((r) => r.title == 'B').status, ChecklistStatus.toAdd);
  });

  test('an empty vault with no placeholders gives no rows', () {
    expect(build(docs: const []), isEmpty);
  });
}