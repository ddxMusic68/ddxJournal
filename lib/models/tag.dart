class Tag {
  final int? id;
  final String name;
  final int color;

  const Tag({this.id, required this.name, required this.color});

  Tag copyWith({int? id, String? name, int? color}) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'color': color};
  }

  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: map['color'] as int,
    );
  }
}
