import '../config/openapi_filters_config.dart';

/// 路径 + 单条 operation 是否通过过滤（对齐 Go `matchesFilters`）。
bool matchesFilters(
  String path,
  List<String> operationTags,
  OpenApiFiltersConfig filters,
) {
  if (!_matchIncludePath(path, filters.includePathPrefixes)) {
    return false;
  }
  if (_matchExcludePath(path, filters.excludePathPrefixes)) {
    return false;
  }
  if (filters.includeTags.isNotEmpty &&
      !_tagMatched(operationTags, filters.includeTags)) {
    return false;
  }
  if (filters.excludeTags.isNotEmpty &&
      _tagMatched(operationTags, filters.excludeTags)) {
    return false;
  }
  return true;
}

bool _matchIncludePath(String path, List<String> includePrefixes) {
  if (includePrefixes.isEmpty) {
    return true;
  }
  for (final prefix in includePrefixes) {
    if (path.startsWith(prefix.trim())) {
      return true;
    }
  }
  return false;
}

bool _matchExcludePath(String path, List<String> excludePrefixes) {
  for (final prefix in excludePrefixes) {
    if (path.startsWith(prefix.trim())) {
      return true;
    }
  }
  return false;
}

bool _tagMatched(List<String> opTags, List<String> wanted) {
  final set = <String>{
    for (final t in opTags) t.trim().toLowerCase(),
  };
  for (final target in wanted) {
    if (set.contains(target.trim().toLowerCase())) {
      return true;
    }
  }
  return false;
}

/// 从 OpenAPI `paths` 下某 path 项收集 HTTP 动词对应的 operation map。
List<Map<String, dynamic>> iterOperations(Map<String, dynamic> pathItem) {
  const methods = [
    'get',
    'put',
    'post',
    'delete',
    'options',
    'head',
    'patch',
    'trace',
  ];
  final out = <Map<String, dynamic>>[];
  for (final m in methods) {
    final op = pathItem[m];
    if (op is Map<String, dynamic>) {
      out.add(op);
    } else if (op is Map) {
      out.add(Map<String, dynamic>.from(op));
    }
  }
  return out;
}

List<String> _tagsFromOperation(Map<String, dynamic> op) {
  final t = op['tags'];
  if (t is! List) {
    return const [];
  }
  return t.map((e) => e.toString()).toList(growable: false);
}

/// 该 path 下是否存在**至少一个**通过过滤的 operation（与 Go 按 operation 过滤一致）。
bool pathHasMatchingOperation(
  String path,
  dynamic pathItem,
  OpenApiFiltersConfig filters,
) {
  if (filters.isEmpty) {
    return true;
  }
  if (pathItem is! Map) {
    return false;
  }
  final item = pathItem is Map<String, dynamic>
      ? pathItem
      : Map<String, dynamic>.from(pathItem);
  final ops = iterOperations(item);
  if (ops.isEmpty) {
    return matchesFilters(path, const [], filters);
  }
  for (final op in ops) {
    if (matchesFilters(path, _tagsFromOperation(op), filters)) {
      return true;
    }
  }
  return false;
}

/// 返回过滤后的 path 键列表（已排序）。
List<String> filterPathKeys(
  Map<String, dynamic> paths,
  OpenApiFiltersConfig filters,
) {
  final keys = <String>[];
  for (final e in paths.entries) {
    final path = e.key.toString();
    if (pathHasMatchingOperation(path, e.value, filters)) {
      keys.add(path);
    }
  }
  keys.sort();
  return keys;
}
