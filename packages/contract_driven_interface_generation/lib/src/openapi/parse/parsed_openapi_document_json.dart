import 'dart:convert';

import 'openapi_parse_models.dart';

/// 将 [ParsedOpenApiDocument] 转为可 `jsonEncode` 的 Map（便于落盘或调试）。
Map<String, dynamic> parsedOpenApiDocumentToJsonMap(ParsedOpenApiDocument d) {
  return <String, dynamic>{
    'rawVersionField': d.rawVersionField,
    'kind': d.kind.name,
    'info': _infoToJson(d.info),
    'servers': [for (final s in d.servers) _serverToJson(s)],
    'swaggerHost': d.swaggerHost,
    'swaggerBasePath': d.swaggerBasePath,
    'swaggerSchemes': d.swaggerSchemes,
    'securitySchemes': _deepJsonEncodable(d.securitySchemes),
    'schemas': {
      for (final e in d.schemas.entries)
        e.key: _deepJsonEncodable(e.value),
    },
    'operations': [for (final o in d.operations) _operationToJson(o)],
    'warnings': d.warnings,
    'filteredPathCount': d.filteredPathCount,
  };
}

/// JSON 字符串（默认带缩进，便于阅读）。
String encodeParsedOpenApiDocumentJson(
  ParsedOpenApiDocument d, {
  bool pretty = true,
}) {
  final map = parsedOpenApiDocumentToJsonMap(d);
  if (pretty) {
    return JsonEncoder.withIndent('  ').convert(map);
  }
  return jsonEncode(map);
}

Map<String, dynamic>? _infoToJson(ParsedOpenApiInfo? i) {
  if (i == null) {
    return null;
  }
  return <String, dynamic>{
    'title': i.title,
    'version': i.version,
    'description': i.description,
  };
}

Map<String, dynamic> _serverToJson(ParsedServer s) {
  return <String, dynamic>{
    'url': s.url,
    'description': s.description,
  };
}

Map<String, dynamic> _parameterToJson(ParsedParameter p) {
  return <String, dynamic>{
    'name': p.name,
    'in': p.inLocation,
    'required': p.required,
    'description': p.description,
    'schemaRef': p.schemaRef,
    'inlineType': p.inlineType,
    'enumValues': p.enumValues,
  };
}

Map<String, dynamic>? _requestBodyToJson(ParsedRequestBodySummary? r) {
  if (r == null) {
    return null;
  }
  return <String, dynamic>{
    'required': r.required,
    'contentTypes': r.contentTypes,
    'jsonSchemaRef': r.jsonSchemaRef,
  };
}

Map<String, dynamic> _responseToJson(ParsedResponseSummary r) {
  return <String, dynamic>{
    'description': r.description,
    'contentTypes': r.contentTypes,
    'jsonSchemaRef': r.jsonSchemaRef,
    'legacySchemaRef': r.legacySchemaRef,
  };
}

Map<String, dynamic> _operationToJson(ParsedOperation o) {
  return <String, dynamic>{
    'path': o.path,
    'method': o.method,
    'operationId': o.operationId,
    'summary': o.summary,
    'description': o.description,
    'tags': o.tags,
    'parameters': [for (final p in o.parameters) _parameterToJson(p)],
    'requestBody': _requestBodyToJson(o.requestBody),
    'responsesByCode': {
      for (final e in o.responsesByCode.entries)
        e.key: _responseToJson(e.value),
    },
    'successJsonSchemaRef': o.successJsonSchemaRef,
    'deprecated': o.deprecated,
  };
}

/// 规范子树中若仍有非 JSON 原生类型，尽量转成可编码结构。
dynamic _deepJsonEncodable(dynamic v) {
  if (v == null || v is num || v is String || v is bool) {
    return v;
  }
  if (v is List) {
    return v.map(_deepJsonEncodable).toList();
  }
  if (v is Map) {
    return <String, dynamic>{
      for (final e in v.entries)
        e.key.toString(): _deepJsonEncodable(e.value),
    };
  }
  return v.toString();
}
