class VaultDocument {
  final String id;
  final String categoryId;
  final String title;
  final String? subtitle; // e.g. "Expires Mar 2031" or "Archived"
  final DateTime? expiryDate;
  final String? encryptedFilePath; // set once a real file is attached
  final String? fileType; // 'image', 'pdf', or 'file' — tells the detail screen how to render it
  final String? fileExtension; // e.g. 'docx', 'xlsx' — used for the icon/label on 'file' types
  final String? memberId; // optional — which family member this document belongs to

  const VaultDocument({
    required this.id,
    required this.categoryId,
    required this.title,
    this.subtitle,
    this.expiryDate,
    this.encryptedFilePath,
    this.fileType,
    this.fileExtension,
    this.memberId,
  });

  /// True if this document expires within [days] days.
  bool expiringWithin(int days) {
    if (expiryDate == null) return false;
    final diff = expiryDate!.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= days;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'title': title,
        'subtitle': subtitle,
        'expiryDate': expiryDate?.toIso8601String(),
        'encryptedFilePath': encryptedFilePath,
        'fileType': fileType,
        'fileExtension': fileExtension,
        'memberId': memberId,
      };

  factory VaultDocument.fromJson(Map<String, dynamic> json) => VaultDocument(
        id: json['id'] as String,
        categoryId: json['categoryId'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String?,
        expiryDate:
            json['expiryDate'] == null ? null : DateTime.parse(json['expiryDate'] as String),
        encryptedFilePath: json['encryptedFilePath'] as String?,
        // Older saved documents won't have this field — assume image,
        // since that was the only option before PDFs were added.
        fileType: json['fileType'] as String? ?? (json['encryptedFilePath'] != null ? 'image' : null),
        fileExtension: json['fileExtension'] as String?,
        memberId: json['memberId'] as String?,
      );
}
