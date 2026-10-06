import 'package:flutter/material.dart';

/// A person documents can be tagged with — e.g. "Dad", "Mum" — within one
/// local vault. Not a login or account; just a label plus a colour for a
/// small initial badge.
class FamilyMember {
  final String id;
  final String name;
  final Color color;

  const FamilyMember({required this.id, required this.name, required this.color});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color.toARGB32(),
      };

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
        id: json['id'] as String,
        name: json['name'] as String,
        color: Color(json['color'] as int),
      );
}

// Rotated through automatically as members are added — keeps colours
// distinct without asking the user to pick one.
const List<Color> memberColorPalette = [
  Color(0xFFB8860B), // brass
  Color(0xFF4A6FA5), // slate blue
  Color(0xFF6B8E5A), // sage green
  Color(0xFFA0527A), // muted plum
  Color(0xFFC77B3C), // terracotta
];
