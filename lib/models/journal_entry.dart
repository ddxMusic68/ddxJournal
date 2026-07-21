import 'dart:convert';

class JournalEntry {
  final int? id;
  final String title;
  final String content;
  final List<String> mediaPaths;
  final List<String> tags;
  final DateTime date;
  final DateTime updatedAt;

  const JournalEntry({
    this.id,
    required this.title,
    required this.content,
    this.mediaPaths = const [],
    this.tags = const [],
    required this.date,
    required this.updatedAt,
  });

  JournalEntry copyWith({
    int? id,
    String? title,
    String? content,
    List<String>? mediaPaths,
    List<String>? tags,
    DateTime? date,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      tags: tags ?? this.tags,
      date: date ?? this.date,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'media_paths': mediaPaths.join(','),
      'date': date.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['id'] as int?,
      title: map['title'] as String,
      content: map['content'] as String,
      mediaPaths: (map['media_paths'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
      date: DateTime.parse(map['date'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  bool get hasTextContent {
    try {
      final data = jsonDecode(content);
      if (data is! List) return false;
      final text = data
          .whereType<Map<String, dynamic>>()
          .map((op) => op['insert'] ?? '')
          .whereType<String>()
          .join();
      return text.trim().isNotEmpty;
    } catch (_) {
      return content.trim().isNotEmpty;
    }
  }
}
