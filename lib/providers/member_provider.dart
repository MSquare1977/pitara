import 'package:flutter/material.dart';
import '../models/member.dart';
import '../repositories/member_repository.dart';

class MemberProvider extends ChangeNotifier {
  final MemberRepository _repository = MemberRepository();

  Future<void> load() async {
    await _repository.load();
    notifyListeners();
  }

  List<FamilyMember> get members => _repository.getAll();

  Color nextColor() => memberColorPalette[members.length % memberColorPalette.length];

  Future<void> addMember(FamilyMember member) async {
    await _repository.add(member);
    notifyListeners();
  }

  Future<void> updateMember(FamilyMember member) async {
    await _repository.update(member);
    notifyListeners();
  }

  Future<void> deleteMember(String id) async {
    await _repository.delete(id);
    notifyListeners();
  }
}
