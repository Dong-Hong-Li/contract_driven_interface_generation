import 'package:contract_driven_interface_generation/contract_driven_interface_generation.dart';

/// 与 Go `resolveGroup` 一致：首 tag → 否则 path 首段 → `common`。
String resolveOperationGroup(ParsedOperation op) {
  const defaultGroup = 'common';
  if (op.tags.isNotEmpty) {
    final g = op.tags.first.trim();
    if (g.isNotEmpty) {
      return g;
    }
  }
  final seg = firstPathSegment(op.path);
  if (seg.isNotEmpty) {
    return seg;
  }
  return defaultGroup;
}

String firstPathSegment(String path) {
  var p = path.trim();
  if (p.startsWith('/')) {
    p = p.substring(1);
  }
  final i = p.indexOf('/');
  final head = i < 0 ? p : p.substring(0, i);
  return head.trim();
}

/// tag → operations（顺序与 [doc.operations] 一致）。
Map<String, List<ParsedOperation>> groupOperations(ParsedOpenApiDocument doc) {
  final out = <String, List<ParsedOperation>>{};
  for (final op in doc.operations) {
    final g = resolveOperationGroup(op);
    out.putIfAbsent(g, () => []).add(op);
  }
  return out;
}
