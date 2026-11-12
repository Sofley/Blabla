import '../../core/utils/file_names.dart';

/// Category of a document in the deal dossier.
enum DocCategory {
  /// Main official contract signed with the client.
  mainContract,
  invoice,

  /// Specifications, lists of goods, annexes with quantities and prices.
  appendix,

  /// Supplementary agreements changing price, quantity, dates, terms…
  supplement,

  /// Corrected invoices / specifications / annexes.
  correction,
  other;

  static DocCategory fromName(String? n) => DocCategory.values.firstWhere(
    (c) => c.name == n,
    orElse: () => DocCategory.other,
  );
}

/// Status of a document.
enum DocStatus {
  /// Действующий.
  active,

  /// Заменённый (by a correction or a newer document).
  replaced,

  /// Аннулированный.
  cancelled;

  static DocStatus fromName(String? n) => DocStatus.values.firstWhere(
    (s) => s.name == n,
    orElse: () => DocStatus.active,
  );
}

/// One uploaded file of a document. Replacing the file adds a version;
/// earlier versions are kept (never deleted by a replacement).
class DocVersion {
  const DocVersion({
    required this.fileId,
    required this.fileName,
    required this.size,
    required this.uploadedAt,
    this.uploadedBy = '',
  });

  /// Id of the encrypted file in the AttachmentStore.
  final String fileId;
  final String fileName;
  final int size;
  final DateTime uploadedAt;
  final String uploadedBy;

  /// Lower-case extension without the dot ("pdf", "docx"…).
  String get format => fileFormat(fileName);

  Map<String, dynamic> toJson() => {
    'fileId': fileId,
    'fileName': fileName,
    'size': size,
    'uploadedAt': uploadedAt.toIso8601String(),
    'uploadedBy': uploadedBy,
  };

  static DocVersion? fromJson(Map<dynamic, dynamic> j) {
    final id = j['fileId'] as String?;
    if (id == null) return null;
    return DocVersion(
      fileId: id,
      fileName: j['fileName'] as String? ?? id,
      size: (j['size'] as num?)?.toInt() ?? 0,
      uploadedAt:
          DateTime.tryParse(j['uploadedAt'] as String? ?? '') ?? DateTime.now(),
      uploadedBy: j['uploadedBy'] as String? ?? '',
    );
  }
}

/// A document of the deal dossier: official contract, invoice, annex,
/// supplementary agreement, correction or other.
class DealDocument {
  const DealDocument({
    required this.id,
    required this.category,
    required this.title,
    this.number = '',
    this.date,
    this.status = DocStatus.active,
    this.visibleToClient = false,
    this.relatedId,
    this.replacesId,
    this.versions = const [],
    required this.createdAt,
  });

  /// Allowed file formats (п. 17.6).
  static const formats = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'jpg',
    'jpeg',
    'png',
  ];

  final String id;
  final DocCategory category;

  /// Name of the document (the file name by default).
  final String title;

  /// Number and date of the document, typed by hand (optional).
  final String number;
  final DateTime? date;
  final DocStatus status;

  /// Shown to the client / partner of the deal (off by default: internal
  /// documents are never given to them automatically).
  final bool visibleToClient;

  /// Main contract document this one belongs to (appendix, supplement…).
  final String? relatedId;

  /// For a correction: the document it corrects (that one becomes
  /// "replaced").
  final String? replacesId;

  /// Uploaded files, oldest first; the last one is current.
  final List<DocVersion> versions;
  final DateTime createdAt;

  DocVersion? get current => versions.isEmpty ? null : versions.last;

  DealDocument copyWith({
    DocCategory? category,
    String? title,
    String? number,
    Object? date = _keep,
    DocStatus? status,
    bool? visibleToClient,
    Object? relatedId = _keep,
    Object? replacesId = _keep,
    List<DocVersion>? versions,
  }) => DealDocument(
    id: id,
    category: category ?? this.category,
    title: title ?? this.title,
    number: number ?? this.number,
    date: identical(date, _keep) ? this.date : date as DateTime?,
    status: status ?? this.status,
    visibleToClient: visibleToClient ?? this.visibleToClient,
    relatedId: identical(relatedId, _keep)
        ? this.relatedId
        : relatedId as String?,
    replacesId: identical(replacesId, _keep)
        ? this.replacesId
        : replacesId as String?,
    versions: versions ?? this.versions,
    createdAt: createdAt,
  );

  static const Object _keep = Object();

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.name,
    'title': title,
    'number': number,
    'date': date?.toIso8601String(),
    'status': status.name,
    'visibleToClient': visibleToClient,
    'relatedId': relatedId,
    'replacesId': replacesId,
    'versions': [for (final v in versions) v.toJson()],
    'createdAt': createdAt.toIso8601String(),
  };

  static DealDocument? fromJson(Map<dynamic, dynamic> j) {
    final id = j['id'] as String?;
    if (id == null) return null;
    return DealDocument(
      id: id,
      category: DocCategory.fromName(j['category'] as String?),
      title: j['title'] as String? ?? '',
      number: j['number'] as String? ?? '',
      date: DateTime.tryParse(j['date'] as String? ?? ''),
      status: DocStatus.fromName(j['status'] as String?),
      visibleToClient: j['visibleToClient'] as bool? ?? false,
      relatedId: j['relatedId'] as String?,
      replacesId: j['replacesId'] as String?,
      versions: [
        for (final v in (j['versions'] as List?) ?? const [])
          if (v is Map) ?DocVersion.fromJson(v),
      ],
      createdAt:
          DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// A plain attachment of the 3.0 test build: becomes an "other" document
  /// with one version; the encrypted file stays where it is.
  static DealDocument? fromLegacyAttachment(Map<dynamic, dynamic> j) {
    final id = j['id'] as String?;
    if (id == null) return null;
    final at =
        DateTime.tryParse(j['addedAt'] as String? ?? '') ?? DateTime.now();
    final name = j['name'] as String? ?? id;
    return DealDocument(
      id: id,
      category: DocCategory.other,
      title: name,
      versions: [
        DocVersion(
          fileId: id,
          fileName: name,
          size: (j['size'] as num?)?.toInt() ?? 0,
          uploadedAt: at,
          uploadedBy: j['addedBy'] as String? ?? '',
        ),
      ],
      createdAt: at,
    );
  }
}
