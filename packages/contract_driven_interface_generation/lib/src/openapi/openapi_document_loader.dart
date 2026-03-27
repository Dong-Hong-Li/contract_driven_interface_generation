import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'yaml_map.dart';

/// 从磁盘加载 OpenAPI JSON 或 YAML，得到与 `copy` 解析层类似的 `Map<String, Object?>`。
final class OpenApiDocumentLoader {
  OpenApiDocumentLoader._();

  /// 根据扩展名判断格式：`.json` → JSON，否则按 YAML 解析。
  static Future<Map<String, dynamic>> loadFile(
      String absoluteOrRelativePath) async {
    final file = File(absoluteOrRelativePath);
    if (!file.existsSync()) {
      throw OpenApiLoadException('File not found: $absoluteOrRelativePath');
    }
    final text = await file.readAsString();
    final ext = p.extension(absoluteOrRelativePath).toLowerCase();
    final isJson = ext == '.json';
    return parseString(text, isJson: isJson);
  }

  static Map<String, dynamic> parseString(String content,
      {required bool isJson}) {
    if (isJson) {
      final decoded = jsonDecode(content);
      if (decoded is! Map) {
        throw OpenApiLoadException('JSON root must be an object');
      }
      return Map<String, dynamic>.from(decoded);
    }
    final root = loadYaml(content);
    if (root == null) {
      return {};
    }
    if (root is! YamlMap) {
      throw OpenApiLoadException('YAML root must be a map');
    }
    return root.toJsonStyleMap();
  }
}

final class OpenApiLoadException implements Exception {
  OpenApiLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}
