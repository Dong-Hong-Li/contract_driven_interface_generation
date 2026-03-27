import 'error_codes_collect.dart';

/// 生成 `openapi_error_codes.dart` 全文。
String renderOpenApiErrorCodesDartFile(CollectedErrorCodes data) {
  final buf = StringBuffer();
  buf.writeln('// GENERATED CODE — DO NOT MODIFY BY HAND');
  buf.writeln();
  buf.writeln('/// OpenAPI 聚合常量：HTTP 状态码 + schema 中 `properties.code.enum`（若有）。');
  buf.writeln('library;');
  buf.writeln();

  if (data.httpStatuses.isEmpty) {
    buf.writeln('/// 文档中未出现可解析的数字型 HTTP 状态码（100–599）。');
    buf.writeln('abstract final class OpenApiHttpStatusCodes {');
    buf.writeln('  OpenApiHttpStatusCodes._();');
    buf.writeln('}');
  } else {
    buf.writeln('/// 文档中出现的 HTTP 状态码。');
    buf.writeln('abstract final class OpenApiHttpStatusCodes {');
    buf.writeln('  OpenApiHttpStatusCodes._();');
    final usedNames = <String>{};
    for (final code in data.httpStatuses) {
      var name = httpStatusConstName(code);
      if (!usedNames.add(name)) {
        name = 'http$code';
        usedNames.add(name);
      }
      buf.writeln();
      buf.writeln('  /// HTTP $code');
      buf.writeln('  static const int $name = $code;');
    }
    buf.writeln('}');
  }

  buf.writeln();
  final bizNamed = assignBusinessConstNames(data.businessValues);
  if (bizNamed.isEmpty) {
    buf.writeln('/// 未在 components schema 中发现 `code` 枚举。');
    buf.writeln('abstract final class OpenApiBusinessErrorCodes {');
    buf.writeln('  OpenApiBusinessErrorCodes._();');
    buf.writeln('}');
  } else {
    buf.writeln('/// 业务错误码（来自各 schema 的 `code` 枚举）。');
    buf.writeln('abstract final class OpenApiBusinessErrorCodes {');
    buf.writeln('  OpenApiBusinessErrorCodes._();');
    for (final row in bizNamed) {
      final name = row.dartName;
      final v = row.entry.value;
      final schema = row.entry.schemaKey;
      buf.writeln();
      buf.writeln('  /// schema `$schema` → $v');
      if (v is int) {
        buf.writeln('  static const int $name = $v;');
      } else {
        buf.writeln('  static const String $name = ${_dartStringLiteral(v.toString())};');
      }
    }
    buf.writeln('}');
  }

  buf.writeln();
  return buf.toString();
}

String _dartStringLiteral(String s) {
  final escaped = s
      .replaceAll(r'\', r'\\')
      .replaceAll(r'$', r'\$')
      .replaceAll("'", r"\'");
  return "'$escaped'";
}
