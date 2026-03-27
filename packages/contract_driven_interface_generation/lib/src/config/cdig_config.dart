import 'dart:io';

import 'package:contract_driven_interface_generation/src/config/cdig_run.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'cdig_config_exception.dart';
import 'cdig_dirs.dart';
import 'openapi_filters_config.dart';

/// 契约驱动生成配置：从 `pubspec.yaml` 或独立 YAML 读取 `contract_driven_interface_generation:`。
///
/// **保留的 YAML 形状**（与 Go `cdig` 模板对齐）：
/// - `output_root`、`dirs`（apis / interfaces / dto / vo）、`tag_to_file_prefix`
/// - 规范来源：`open_api_files`（列表，必填；路径相对 **pubspec / 配置文件所在目录**，即项目根，
///   与在子目录执行 `dart run` 时的终端 cwd 无关）
/// - 可选：`openapi.filters`（与原先过滤语义相同）
/// - 可选：`client` → 生成 `@NetApi(client: '...')`（与 `net_retrofit_dio` 一致）
/// - 可选：`unwrap_success_data`（默认 `true`）→ `false` 时返回完整包装 schema（含 code/message），不生成 `@DataPath`，便于解析业务错误码
final class CdigConfig {
  const CdigConfig({
    required this.loadedYamlPath,
    required this.outputRoot,
    required this.dirs,
    required this.tagToFilePrefix,
    required this.openApiFilesRelative,
    this.filters = OpenApiFiltersConfig.empty,
    this.client,
    this.unwrapSuccessData = true,
  });

  /// 实际加载的 YAML 文件绝对路径
  final String loadedYamlPath;

  /// 生成根目录（YAML 内为相对 [configDirectory] 的路径，一般为项目根）
  final String outputRoot;

  final CdigDirs dirs;

  /// tag → 文件名前缀（snake_case 映射由生成器使用）
  final Map<String, String> tagToFilePrefix;

  /// OpenAPI 文件路径（与 YAML 中一致，相对 [configDirectory]）
  final List<String> openApiFilesRelative;

  /// `openapi.filters`
  final OpenApiFiltersConfig filters;

  /// 对应 `net_retrofit_dio` [@NetApi] 的 `client`（lane id）；未配置则 `@NetApi()`。
  final String? client;

  /// `true`（默认）：成功响应只反序列化 `data`/`result` 内层，生成 `@DataPath`。
  /// `false`：返回 OpenAPI 中 200 的完整包装类型（如 `XxxApiResponse`），便于读 `code`/`message`。
  final bool unwrapSuccessData;

  /// 配置文件所在目录（用于解析相对路径）
  String get configDirectory => p.dirname(loadedYamlPath);

  /// 在 [Directory.current] 下查找配置文件并解析。
  static Future<CdigConfig> load({String? configFile}) async {
    final file = findCdigConfigFile(explicitPath: configFile);
    if (file == null) {
      throw CdigConfigException(
        '找不到配置：请使用 -f / --config 指定 pubspec.yaml，'
        '或在项目根放置含 contract_driven_interface_generation 段的 pubspec.yaml / '
        '$cdigDefaultYamlFileName（也可在子目录执行，工具会向上查找）。',
      );
    }
    final text = await file.readAsString();
    final root = loadYaml(text);
    if (root is! YamlMap) {
      throw CdigConfigException(
        'Config root must be a YAML map: ${file.path}',
      );
    }
    return parseRoot(root, loadedYamlPath: p.canonicalize(file.absolute.path));
  }

  /// 从已解析的 YAML 根对象提取 [cdigPubspecKey] 段（供测试或自定义加载）。
  static CdigConfig parseRoot(
    YamlMap root, {
    required String loadedYamlPath,
  }) {
    final section = root[cdigPubspecKey];
    if (section == null) {
      throw CdigConfigException(
        "`${p.basename(loadedYamlPath)}` has no '$cdigPubspecKey' section.",
      );
    }
    if (section is! YamlMap) {
      throw CdigConfigException(
        "'$cdigPubspecKey' must be a YAML map.",
      );
    }
    return _parseSection(section, loadedYamlPath: loadedYamlPath);
  }

  static CdigConfig _parseSection(
    YamlMap section, {
    required String loadedYamlPath,
  }) {
    final outRoot = _requireNonEmptyString(
      section['output_root'],
      field: 'output_root',
    );
    final dirs = CdigDirs.parse(section['dirs']);
    final tagMap = _parseTagToFilePrefix(section['tag_to_file_prefix']);
    final files = _parseOpenApiFiles(section);
    final openapiNode = section['openapi'];
    YamlMap? openapiMap;
    if (openapiNode == null) {
      openapiMap = null;
    } else if (openapiNode is YamlMap) {
      openapiMap = openapiNode;
      _assertOpenApiOnlyFilters(openapiMap);
    } else {
      throw FormatException(
        'contract_driven_interface_generation.openapi must be a YAML map or omitted',
      );
    }

    return CdigConfig(
      loadedYamlPath: loadedYamlPath,
      outputRoot: outRoot,
      dirs: dirs,
      tagToFilePrefix: tagMap,
      openApiFilesRelative: files,
      filters: OpenApiFiltersConfig.parse(openapiMap?['filters']),
      client: _parseOptionalClient(section['client']),
      unwrapSuccessData: _parseUnwrapSuccessData(section['unwrap_success_data']),
    );
  }

  /// 未配置时默认 `true`（保持历史行为：只取 data）。
  static bool _parseUnwrapSuccessData(dynamic v) {
    if (v == null) {
      return true;
    }
    if (v is bool) {
      return v;
    }
    final s = v.toString().trim().toLowerCase();
    if (s == 'false' || s == '0' || s == 'no') {
      return false;
    }
    if (s == 'true' || s == '1' || s == 'yes' || s.isEmpty) {
      return true;
    }
    throw FormatException(
      'contract_driven_interface_generation.unwrap_success_data must be a boolean',
    );
  }

  static String? _parseOptionalClient(dynamic v) {
    if (v == null) {
      return null;
    }
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static void _assertOpenApiOnlyFilters(YamlMap openapiMap) {
    for (final key in openapiMap.keys) {
      if (key.toString() != 'filters') {
        throw FormatException(
          'contract_driven_interface_generation.openapi 仅允许 filters 子键；'
          '请将 output_root、dirs、tag_to_file_prefix、open_api_files 写在段根。',
        );
      }
    }
  }

  static String _requireNonEmptyString(dynamic v, {required String field}) {
    if (v == null) {
      throw FormatException(
        'contract_driven_interface_generation.$field is required',
      );
    }
    final s = v.toString().trim();
    if (s.isEmpty) {
      throw FormatException(
        'contract_driven_interface_generation.$field cannot be empty',
      );
    }
    return s;
  }

  static Map<String, String> _parseTagToFilePrefix(dynamic node) {
    if (node == null) {
      return const {};
    }
    if (node is! YamlMap) {
      throw FormatException(
        'contract_driven_interface_generation.tag_to_file_prefix must be a YAML map or omitted',
      );
    }
    final out = <String, String>{};
    for (final e in node.entries) {
      final k = e.key.toString().trim();
      final v = e.value.toString().trim();
      if (k.isNotEmpty && v.isNotEmpty) {
        out[k] = v;
      }
    }
    return out;
  }

  static List<String> _parseOpenApiFiles(YamlMap section) {
    final list = _stringList(section['open_api_files']);
    if (list.isEmpty) {
      throw FormatException(
        'contract_driven_interface_generation.open_api_files 必填（至少一个 OpenAPI 文件）；'
        '单文件示例: open_api_files: [specs/api.yaml]',
      );
    }
    return list;
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

  /// 将 [relativeOrAbsolute] 解析为绝对路径：绝对则规范化，否则相对 [configDirectory]（配置文件所在目录）。
  String resolvePath(String relativeOrAbsolute) {
    if (p.isAbsolute(relativeOrAbsolute)) {
      return p.normalize(relativeOrAbsolute);
    }
    return p.normalize(p.join(configDirectory, relativeOrAbsolute));
  }

  /// [outputRoot] 的绝对路径。
  String resolvedOutputRootAbsolute() => resolvePath(outputRoot);

  /// 各 OpenAPI 文件的绝对路径（顺序与配置一致）。
  List<String> resolvedOpenApiAbsolutePaths() =>
      [for (final f in openApiFilesRelative) resolvePath(f)];
}
