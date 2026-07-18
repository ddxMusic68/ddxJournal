class JournalEntry {
  final int? id;
  final String title;
  final String content;
  final List<String> mediaPaths;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JournalEntry({
    this.id,
    required this.title,
    required this.content,
    this.mediaPaths = const [],
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  JournalEntry copyWith({
    int? id,
    String? title,
    String? content,
    List<String>? mediaPaths,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'media_paths': mediaPaths.join(','),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['id'] as int?,
      title: map['title'] as String,
      content: map['content'] as String,
      mediaPaths: (map['media_paths'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
