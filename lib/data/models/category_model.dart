import 'dart:convert';

/// Category model representing Odoo 19 `pos.category`.
class CategoryModel {
  final int id;
  final String name;
  final int? parentId;
  final List<int> childIds;
  final int sequence;

  const CategoryModel({
    required this.id,
    required this.name,
    this.parentId,
    this.childIds = const [],
    this.sequence = 0,
  });

  /// Factory constructor from Odoo 19 JSON-RPC `search_read` record.
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    int? parsedParentId;
    final parent = json['parent_id'];
    if (parent is List && parent.isNotEmpty) {
      parsedParentId = parent[0] as int?;
    } else if (parent is int) {
      parsedParentId = parent;
    }

    List<int> parsedChildIds = [];
    final children = json['child_ids'];
    if (children is List) {
      parsedChildIds = children.whereType<int>().toList();
    }

    return CategoryModel(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      parentId: parsedParentId,
      childIds: parsedChildIds,
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
    );
  }

  /// Converts model to standard JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'child_ids': childIds,
      'sequence': sequence,
    };
  }

  /// Factory constructor from SQLite `cached_categories` table row.
  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    List<int> parsedChildIds = [];
    final rawChildren = map['child_ids'];
    if (rawChildren is String && rawChildren.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawChildren);
        if (decoded is List) {
          parsedChildIds = decoded.whereType<int>().toList();
        }
      } catch (_) {
        parsedChildIds = [];
      }
    }

    return CategoryModel(
      id: map['id'] as int,
      name: (map['name'] ?? '') as String,
      parentId: map['parent_id'] as int?,
      childIds: parsedChildIds,
      sequence: (map['sequence'] as num?)?.toInt() ?? 0,
    );
  }

  /// Converts model to SQLite `cached_categories` table row.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'child_ids': jsonEncode(childIds),
      'sequence': sequence,
    };
  }

  CategoryModel copyWith({
    int? id,
    String? name,
    int? parentId,
    List<int>? childIds,
    int? sequence,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      childIds: childIds ?? this.childIds,
      sequence: sequence ?? this.sequence,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          parentId == other.parentId &&
          sequence == other.sequence;

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ parentId.hashCode ^ sequence.hashCode;

  @override
  String toString() =>
      'CategoryModel(id: $id, name: $name, parentId: $parentId, sequence: $sequence)';
}
