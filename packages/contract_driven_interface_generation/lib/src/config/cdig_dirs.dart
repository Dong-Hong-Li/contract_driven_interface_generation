import 'package:yaml/yaml.dart';

/// 生成目录布局（与 Go `cdig` `targets[].dirs` 默认一致）。
final class CdigDirs {
  const CdigDirs({
    required this.apis,
    required this.interfaces,
    required this.dto,
    required this.vo,
    required this.errorCodes,
  });

  static const CdigDirs defaults = CdigDirs(
    apis: 'apis',
    interfaces: 'interfaces',
    dto: 'models/dto',
    vo: 'models/vo',
    errorCodes: 'error_codes',
  );

  final String apis;
  final String interfaces;
  final String dto;
  final String vo;

  /// 生成 `openapi_error_codes.dart` 等聚合常量的子目录（相对 [output_root]）。
  /// 配置为空字符串 `''` 或 YAML `null` 时不生成错误码文件。
  final String errorCodes;

  static CdigDirs parse(dynamic node) {
    if (node == null) {
      return defaults;
    }
    if (node is! YamlMap) {
      throw FormatException(
        'contract_driven_interface_generation.dirs must be a YAML map or omitted',
      );
    }
    return CdigDirs(
      apis: _str(node['apis'], defaults.apis),
      interfaces: _str(node['interfaces'], defaults.interfaces),
      dto: _str(node['dto'], defaults.dto),
      vo: _str(node['vo'], defaults.vo),
      errorCodes: _parseErrorCodes(node),
    );
  }

  /// 省略键 → 默认 `error_codes`；显式 `null` / `''` → 不生成。
  static String _parseErrorCodes(YamlMap node) {
    if (!node.containsKey('error_codes')) {
      return defaults.errorCodes;
    }
    final v = node['error_codes'];
    if (v == null) {
      return '';
    }
    return v.toString().trim();
  }

  static String _str(dynamic v, String fallback) {
    if (v == null) {
      return fallback;
    }
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  @override
  bool operator ==(Object other) =>
      other is CdigDirs &&
      apis == other.apis &&
      interfaces == other.interfaces &&
      dto == other.dto &&
      vo == other.vo &&
      errorCodes == other.errorCodes;

  @override
  int get hashCode => Object.hash(apis, interfaces, dto, vo, errorCodes);
}
