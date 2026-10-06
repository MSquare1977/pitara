import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/member.dart';

/// Same pattern as CategoryRepository and DocumentRepository.
class MemberRepository {
  static const _storageKey = 'pitara_members';

  List<FamilyMember> _members = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null) {
      _members = []; // no members by default — purely opt-in feature
      await _save();
    } else {
      final decoded = jsonDecode(raw) as List;
      _members = decoded.map((e) => FamilyMember.fromJson(e as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_members.map((m) => m.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  List<FamilyMember> getAll() => List.unmodifiable(_members);

  Future<void> add(FamilyMember member) async {
    _members.add(member);
    await _save();
  }

  Future<void> update(FamilyMember member) async {
    final index = _members.indexWhere((m) => m.id == member.id);
    if (index != -1) _members[index] = member;
    await _save();
  }

  Future<void> delete(String id) async {
    _members.removeWhere((m) => m.id == id);
    await _save();
  }
}
