/// A row the user added to the checklist for a document they still need
/// (or want to track). Documents already in the vault do NOT need one —
/// they appear in the checklist automatically.
class PlannedItem {
  final String id;
  final String name;
  final String? categoryId; // the folder it will live in
  final DateTime? dueDate; // optional "get this by" date
  final String? linkedDocumentId; // set once the real document is attached

  const PlannedItem({
    required this.id,
    required this.name,
    this.categoryId,
    this.dueDate,
    this.linkedDocumentId,
  });

  PlannedItem copyWith({
    String? name,
    String? categoryId,
    DateTime? dueDate,
    String? linkedDocumentId,
    bool clearDueDate = false,
    bool clearLink = false,
  }) {
    return PlannedItem(
      id: id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      linkedDocumentId: clearLink ? null : (linkedDocumentId ?? this.linkedDocumentId),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'categoryId': categoryId,
        'dueDate': dueDate?.toIso8601String(),
        'linkedDocumentId': linkedDocumentId,
      };

  factory PlannedItem.fromJson(Map<String, dynamic> json) => PlannedItem(
        id: json['id'] as String,
        name: json['name'] as String,
        categoryId: json['categoryId'] as String?,
        dueDate: json['dueDate'] == null ? null : DateTime.parse(json['dueDate'] as String),
        linkedDocumentId: json['linkedDocumentId'] as String?,
      );
}