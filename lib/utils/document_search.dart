import 'dart:math';
import '../models/document.dart';
import '../models/category.dart';
import '../models/member.dart';

/// Searches document LABELS only — title, subtitle (e.g. "Expires Mar 2031"),
/// category name and person name. It does not read inside files; that is a
/// separate, later feature (see FEATURE_BACKLOG.md, "Search inside documents").
///
/// How a query is matched:
///  * It is split into words. EVERY word must match somewhere, in any order,
///    so "british passport" finds "Passport (British)".
///  * Capitals and accents are ignored: "resume" finds "Résumé".
///  * A word matches if it equals, starts, or sits inside a word in the
///    document, so "pass" finds "Passport".
///  * Words of 4+ letters also tolerate a small typo: "pasport" finds
///    "Passport". Short words never match fuzzily, to avoid false hits.
///  * "expiring", "renew" and "soon" still mean "due within 90 days".
///  * Better matches are listed first: title beats person/subtitle beats
///    category, and exact beats partial beats typo.
List<VaultDocument> searchDocuments({
  required String query,
  required List<VaultDocument> documents,
  required List<DocCategory> categories,
  List<FamilyMember> members = const [],
}) {
  final queryTokens = _tokens(query);
  if (queryTokens.isEmpty) return [];

  final categoryNameById = {for (final c in categories) c.id: c.name};
  final memberNameById = {for (final m in members) m.id: m.name};

  final scored = <_Scored>[];
  for (var i = 0; i < documents.length; i++) {
    final doc = documents[i];
    final fields = <_Field>[
      _Field(_tokens(doc.title), _titleWeight),
      _Field(_tokens(doc.subtitle ?? ''), _subtitleWeight),
      _Field(_tokens(memberNameById[doc.memberId] ?? ''), _personWeight),
      _Field(_tokens(categoryNameById[doc.categoryId] ?? ''), _categoryWeight),
    ];
    final score = _scoreDocument(queryTokens, fields, doc);
    if (score != null) scored.add(_Scored(doc, score, i));
  }

  // Dart's sort is not guaranteed stable, so ties fall back to the original
  // order explicitly.
  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.index.compareTo(b.index);
  });
  return scored.map((s) => s.document).toList();
}

// --- weights -----------------------------------------------------------

const double _titleWeight = 3.0;
const double _subtitleWeight = 2.0;
const double _personWeight = 2.0;
const double _categoryWeight = 1.0;
const double _expiryShortcutScore = 1.5;
const int _expiryWindowDays = 90;

class _Field {
  final List<String> tokens;
  final double weight;
  const _Field(this.tokens, this.weight);
}

class _Scored {
  final VaultDocument document;
  final double score;
  final int index;
  const _Scored(this.document, this.score, this.index);
}

/// Total score if EVERY query word matched, otherwise null.
double? _scoreDocument(List<String> queryTokens, List<_Field> fields, VaultDocument doc) {
  var total = 0.0;
  for (final q in queryTokens) {
    var best = 0.0;
    for (final field in fields) {
      for (final t in field.tokens) {
        final quality = _tokenMatchQuality(q, t);
        if (quality > 0) best = max(best, quality * field.weight);
      }
    }
    // "expiring" / "renew" / "soon" also match anything due within 90 days,
    // even when those words appear nowhere in the document's text.
    if (best == 0 && _isExpiryWord(q) && doc.expiringWithin(_expiryWindowDays)) {
      best = _expiryShortcutScore;
    }
    if (best == 0) return null; // this word matched nothing: not a result
    total += best;
  }
  return total;
}

bool _isExpiryWord(String q) =>
    q.startsWith('expir') || q.startsWith('renew') || q == 'soon';

/// 0 = no match; otherwise higher is better.
double _tokenMatchQuality(String q, String t) {
  if (t == q) return 1.0;
  if (t.startsWith(q)) return 0.95;
  // A single letter only matches at the start of a word; inside a word it
  // would match almost everything.
  if (q.length >= 2 && t.contains(q)) return 0.8;

  if (q.length >= 4) {
    final maxEdits = q.length >= 8 ? 2 : 1;
    if (_editDistance(q, t, maxEdits) <= maxEdits) return 0.5;
    // A typo in a word that is only partly typed: "passpo" -> "passport".
    if (t.length > q.length) {
      final prefix = t.substring(0, q.length);
      if (_editDistance(q, prefix, maxEdits) <= maxEdits) return 0.4;
    }
  }
  return 0.0;
}

// --- text helpers -------------------------------------------------------

// Letters, combining marks (needed for scripts such as Devanagari) and digits
// make up words; everything else separates them.
final RegExp _separator = RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true);

List<String> _tokens(String input) =>
    _fold(input).split(_separator).where((t) => t.isNotEmpty).toList();

/// Lowercases and strips common Latin accents. No extra package needed.
String _fold(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_accentMap[ch] ?? ch);
  }
  return buffer.toString();
}

const Map<String, String> _accentMap = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
  'ç': 'c', 'ć': 'c', 'č': 'c',
  'ď': 'd',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ę': 'e', 'ě': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
  'ł': 'l',
  'ñ': 'n', 'ń': 'n', 'ň': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'ő': 'o',
  'ř': 'r',
  'ś': 's', 'š': 's',
  'ť': 't',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u',
  'ý': 'y', 'ÿ': 'y',
  'ź': 'z', 'ż': 'z', 'ž': 'z',
  'ß': 'ss', 'æ': 'ae', 'œ': 'oe',
};

/// Edit distance counting a swap of two neighbouring letters as one edit
/// ("pasport" vs "passport" = 1; "pasrport" vs "passport" = 1).
/// Gives up early and returns maxDistance + 1 when the lengths already differ
/// too much.
int _editDistance(String a, String b, int maxDistance) {
  if ((a.length - b.length).abs() > maxDistance) return maxDistance + 1;

  final rows = a.length + 1;
  final cols = b.length + 1;
  final d = List.generate(rows, (_) => List<int>.filled(cols, 0));
  for (var i = 0; i < rows; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j < cols; j++) {
    d[0][j] = j;
  }

  for (var i = 1; i < rows; i++) {
    for (var j = 1; j < cols; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var value = min(min(d[i - 1][j] + 1, d[i][j - 1] + 1), d[i - 1][j - 1] + cost);
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        value = min(value, d[i - 2][j - 2] + 1);
      }
      d[i][j] = value;
    }
  }
  return d[rows - 1][cols - 1];
}