import 'package:yaml/yaml.dart';

/// 路径 / tag 过滤（写在 `openapi.filters`；`schema_path` 等在**段根**，与 Go 模板一致）。
///
/// 与 Go `matchesFilters` 一致：先 `include_path_prefixes`，再 `exclude_path_prefixes`，
/// 再 tag；`include_tags` 与 `exclude_tags` 可同时存在（AND 语义）。
///
/// ```yaml
/// contract_driven_interface_generation:
///   schema_path: specs/api.yaml
///   openapi:
///     filters:
///       include_path_prefixes: [/admin]
///       exclude_path_prefixes: []
///       include_tags: [Admin]
///       exclude_tags: []
/// ```
final class OpenApiFiltersConfig {
  const OpenApiFiltersConfig({
    this.includePathPrefixes = const [],
    this.excludePathPrefixes = const [],
    this.includeTags = const [],
    this.excludeTags = const [],
  });

  /// 包含的路径前缀
  final List<String> includePathPrefixes;

  /// 排除的路径前缀
  final List<String> excludePathPrefixes;

  /// 包含的标签
  final List<String> includeTags;

  /// 排除的标签
  final List<String> excludeTags;

  static const OpenApiFiltersConfig empty = OpenApiFiltersConfig();

  static OpenApiFiltersConfig parse(dynamic node) {
    if (node == null) {
      return empty;
    }
    if (node is! YamlMap) {
      throw FormatException('openapi.filters must be a YAML map');
    }
    return OpenApiFiltersConfig(
      includePathPrefixes: _stringList(node['include_path_prefixes']),
      excludePathPrefixes: _stringList(node['exclude_path_prefixes']),
      includeTags: _stringList(node['include_tags']),
      excludeTags: _stringList(node['exclude_tags']),
    );
  }

  static List<String> _stringList(dynamic v) {
    if (v is! YamlList) {
      return const [];
    }
    return v
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  bool get isEmpty =>
      includePathPrefixes.isEmpty &&
      excludePathPrefixes.isEmpty &&
      includeTags.isEmpty &&
      excludeTags.isEmpty;
}
