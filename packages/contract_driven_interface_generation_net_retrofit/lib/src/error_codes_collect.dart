import 'package:contract_driven_interface_generation/contract_driven_interface_generation.dart';

import 'name_utils.dart';

/// 从 OpenAPI 文档聚合 HTTP 状态码（数字）与 components schema 里 `code` 的 enum。
final class CollectedErrorCodes {
  const CollectedErrorCodes({
    required this.httpStatuses,
    required this.businessValues,
  });

  /// 出现在任意 operation response 中的 HTTP 状态码（100–599）。
  final List<int> httpStatuses;

  /// schema 名（Dart 友好）→ 该 schema 下收集到的 `code` 枚举值（int 或 String）。
  final List<BusinessCodeEntry> businessValues;
}

final class BusinessCodeEntry {
  const BusinessCodeEntry({
    required this.schemaKey,
    required this.value,
  });

  final String schemaKey;
  final Object value;
}

CollectedErrorCodes collectErrorCodes(ParsedOpenApiDocument document) {
  final http = <int>{};
  for (final op in document.operations) {
    for (final code in op.responsesByCode.keys) {
      if (code == 'default') {
        continue;
      }
      final n = int.tryParse(code);
      if (n != null && n >= 100 && n <= 599) {
        http.add(n);
      }
    }
  }
  final sortedHttp = http.toList()..sort();

  final biz = <BusinessCodeEntry>[];
  final seenBiz = <String>{};
  for (final e in document.schemas.entries) {
    _collectCodeEnumsFromSchema(
      e.value,
      (values) {
        for (final v in values) {
          final key = '${e.key}::$v';
          if (seenBiz.add(key)) {
            biz.add(BusinessCodeEntry(schemaKey: e.key, value: v as Object));
          }
        }
      },
    );
  }
  biz.sort((a, b) {
    final c = a.schemaKey.compareTo(b.schemaKey);
    if (c != 0) {
      return c;
    }
    return a.value.toString().compareTo(b.value.toString());
  });

  return CollectedErrorCodes(
    httpStatuses: sortedHttp,
    businessValues: biz,
  );
}

void _collectCodeEnumsFromSchema(
  Map<String, dynamic> sch,
  void Function(List<dynamic> values) emit,
) {
  final props = sch['properties'];
  if (props is Map) {
    final pm = Map<String, dynamic>.from(props);
    final codeNode = pm['code'];
    if (codeNode is Map) {
      final cm = Map<String, dynamic>.from(codeNode);
      final en = cm['enum'];
      if (en is List && en.isNotEmpty) {
        emit(List<dynamic>.from(en));
      }
    }
  }

  for (final key in ['allOf', 'oneOf', 'anyOf']) {
    final v = sch[key];
    if (v is! List) {
      continue;
    }
    for (final item in v) {
      if (item is Map<String, dynamic>) {
        _collectCodeEnumsFromSchema(item, emit);
      } else if (item is Map) {
        _collectCodeEnumsFromSchema(
          Map<String, dynamic>.from(item),
          emit,
        );
      }
    }
  }
}

/// HTTP 状态码 → Dart 常量名（小驼峰）。
String httpStatusConstName(int code) {
  const known = <int, String>{
    100: 'continue_',
    101: 'switchingProtocols',
    200: 'ok',
    201: 'created',
    202: 'accepted',
    204: 'noContent',
    206: 'partialContent',
    301: 'movedPermanently',
    302: 'found',
    304: 'notModified',
    400: 'badRequest',
    401: 'unauthorized',
    403: 'forbidden',
    404: 'notFound',
    405: 'methodNotAllowed',
    409: 'conflict',
    410: 'gone',
    422: 'unprocessableEntity',
    429: 'tooManyRequests',
    500: 'internalServerError',
    501: 'notImplemented',
    502: 'badGateway',
    503: 'serviceUnavailable',
    504: 'gatewayTimeout',
  };
  return known[code] ?? 'http$code';
}

/// 业务 code 枚举 → 唯一 Dart 标识符（lowerCamelCase）。
String businessCodeConstName(String schemaKey, Object value, int disambig) {
  final schemaSnake = toSnake(refToDartName(schemaKey));
  final mid = value is int
      ? '${schemaSnake}_$value'
      : '${schemaSnake}_${_enumValueToSnake(value.toString())}';
  var camel = _snakeToLowerCamel(mid);
  if (disambig > 0) {
    camel = '${camel}_$disambig';
  }
  return camel;
}

String _snakeToLowerCamel(String snake) {
  final parts = snake.split('_').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) {
    return 'x';
  }
  final buf = StringBuffer(parts.first);
  for (final p in parts.skip(1)) {
    if (p.isEmpty) {
      continue;
    }
    buf.write(p[0].toUpperCase());
    if (p.length > 1) {
      buf.write(p.substring(1));
    }
  }
  return buf.toString();
}

/// 将枚举字面量（如 `INVALID_TOKEN`）转为 snake 片段，再与 schema 前缀拼接。
String _enumValueToSnake(String s) {
  final parts = s
      .trim()
      .split(RegExp(r'[^a-zA-Z0-9]+'))
      .where((p) => p.isNotEmpty)
      .map((p) => p.toLowerCase())
      .toList();
  if (parts.isEmpty) {
    return 'x';
  }
  var out = parts.join('_');
  if (RegExp(r'^[0-9]').hasMatch(out)) {
    out = 'c_$out';
  }
  return out;
}

/// 分配唯一业务常量名（处理冲突）。
List<({BusinessCodeEntry entry, String dartName})> assignBusinessConstNames(
  List<BusinessCodeEntry> entries,
) {
  final used = <String>{};
  final out = <({BusinessCodeEntry entry, String dartName})>[];
  for (final e in entries) {
    var disambig = 0;
    late String name;
    while (true) {
      name = businessCodeConstName(e.schemaKey, e.value, disambig);
      if (used.add(name)) {
        break;
      }
      disambig++;
    }
    out.add((entry: e, dartName: name));
  }
  return out;
}
