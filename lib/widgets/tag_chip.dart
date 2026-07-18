import 'package:flutter/material.dart';

class TagChip extends StatelessWidget {
  final String name;
  final int color;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TagChip({
    super.key,
    required this.name,
    this.color = 0xFFCCC2DC,
    this.selected = false,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (onDelete != null) {
      return InputChip(
        label: Text(name),
        selected: selected,
        onPressed: onTap,
        deleteIcon: const Icon(Icons.close, size: 18),
        onDeleted: onDelete,
        backgroundColor: Color(color).withValues(alpha: 0.3),
        selectedColor: Color(color),
      );
    }
    return FilterChip(
      label: Text(name),
      selected: selected,
      onSelected: onTap != null ? (_) => onTap!() : null,
      backgroundColor: Color(color).withValues(alpha: 0.3),
      selectedColor: Color(color),
    );
  }
}
