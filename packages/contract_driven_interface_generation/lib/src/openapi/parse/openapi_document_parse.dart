import '../../config/openapi_filters_config.dart';
import '../openapi_path_filter.dart';
import 'openapi_parse_models.dart';
import 'schema_ref.dart';

const _httpMethods = [
  'get',
  'put',
  'post',
  'delete',
  'options',
  'head',
  'patch',
  'trace',
];

/// 将已加载的 OpenAPI/Swagger Map 解析为 [ParsedOpenApiDocument]。
///
/// [filters] 与 [matchesFilters] 一致，按 **operation** 粒度过滤。
ParsedOpenApiDocument parseOpenApiDocument(
  Map<String, dynamic> spec, {
  OpenApiFiltersConfig filters = OpenApiFiltersConfig.empty,
}) {
  final warnings = collectExternalRefWarnings(spec);
  final rawVer =
      spec['openapi']?.toString() ?? spec['swagger']?.toString() ?? '?';
  final kind = _detectKind(spec);
  final info = _parseInfo(spec['info']);
  final servers = _parseServersOas3(spec['servers']);
  final swaggerHost = spec['host']?.toString();
  final swaggerBasePath = spec['basePath']?.toString();
  final swaggerSchemes = _stringListOrEmpty(spec['schemes']);
  final securitySchemes = _parseSecuritySchemes(spec);

  final registry = buildSchemaRegistry(spec);
  final operations = <ParsedOperation>[];
  final pathsHit = <String>{};

  final paths = spec['paths'];
  if (paths is Map) {
    final pathMap = paths is Map<String, dynamic>
        ? paths
        : Map<String, dynamic>.from(paths);
    for (final pe in pathMap.entries) {
      final path = pe.key.toString();
      final pathItem = pe.value;
      if (pathItem is! Map) {
        continue;
      }
      final item = pathItem is Map<String, dynamic>
          ? pathItem
          : Map<String, dynamic>.from(pathItem);
      final pathLevelParams = _parametersList(item['parameters']);
      for (final method in _httpMethods) {
        final opRaw = item[method];
        if (opRaw is! Map) {
          continue;
        }
        final op = opRaw is Map<String, dynamic>
            ? opRaw
            : Map<String, dynamic>.from(opRaw);
        final tags = _tagsFromOp(op);
        if (!matchesFilters(path, tags, filters)) {
          continue;
        }
        pathsHit.add(path);
        final mergedParams =
            _mergeParameters(pathLevelParams, _parametersList(op['parameters']));
        final parameters =
            mergedParams.map((p) => _parseParameter(p, kind)).toList();
        final requestBody = _parseRequestBody(op['requestBody']);
        final responses = _parseResponses(op['responses'], kind);
        final successRef = _pickSuccessJsonRef(responses);
        operations.add(
          ParsedOperation(
            path: path,
            method: method,
            operationId: op['operationId']?.toString(),
            summary: op['summary']?.toString(),
            description: op['description']?.toString(),
            tags: tags,
            parameters: parameters,
            requestBody: requestBody,
            responsesByCode: responses,
            successJsonSchemaRef: successRef,
            deprecated: op['deprecated'] == true,
          ),
        );
      }
    }
  }

  operations.sort((a, b) {
    final c = a.path.compareTo(b.path);
    if (c != 0) {
      return c;
    }
    return a.method.compareTo(b.method);
  });

  return ParsedOpenApiDocument(
    rawVersionField: rawVer,
    kind: kind,
    info: info,
    servers: servers,
    swaggerHost: swaggerHost,
    swaggerBasePath: swaggerBasePath,
    swaggerSchemes: swaggerSchemes,
    securitySchemes: securitySchemes,
    schemas: registry,
    operations: operations,
    warnings: warnings,
    filteredPathCount: pathsHit.length,
  );
}

OpenApiSpecKind _detectKind(Map<String, dynamic> spec) {
  if (spec.containsKey('openapi')) {
    return OpenApiSpecKind.openApi3;
  }
  if (spec['swagger']?.toString() == '2.0') {
    return OpenApiSpecKind.swagger2;
  }
  if (spec.containsKey('swagger')) {
    return OpenApiSpecKind.swagger2;
  }
  return OpenApiSpecKind.unknown;
}

ParsedOpenApiInfo? _parseInfo(dynamic info) {
  if (info is! Map) {
    return null;
  }
  final m =
      info is Map<String, dynamic> ? info : Map<String, dynamic>.from(info);
  return ParsedOpenApiInfo(
    title: m['title']?.toString(),
    version: m['version']?.toString(),
    description: m['description']?.toString(),
  );
}

List<ParsedServer> _parseServersOas3(dynamic servers) {
  if (servers is! List) {
    return const [];
  }
  final out = <ParsedServer>[];
  for (final s in servers) {
    if (s is! Map) {
      continue;
    }
    final m = s is Map<String, dynamic> ? s : Map<String, dynamic>.from(s);
    out.add(
      ParsedServer(
        url: m['url']?.toString(),
        description: m['description']?.toString(),
      ),
    );
  }
  return out;
}

List<String> _stringListOrEmpty(dynamic v) {
  if (v is! List) {
    return const [];
  }
  return v.map((e) => e.toString()).toList(growable: false);
}

Map<String, dynamic> _parseSecuritySchemes(Map<String, dynamic> spec) {
  final comp = spec['components'];
  if (comp is Map && comp['securitySchemes'] is Map) {
    final m = comp['securitySchemes'] as Map;
    return {for (final e in m.entries) e.key.toString(): e.value};
  }
  final secDef = spec['securityDefinitions'];
  if (secDef is Map) {
    return {for (final e in secDef.entries) e.key.toString(): e.value};
  }
  return {};
}

List<String> _tagsFromOp(Map<String, dynamic> op) {
  final t = op['tags'];
  if (t is! List) {
    return const [];
  }
  return t.map((e) => e.toString()).toList(growable: false);
}

List<Map<String, dynamic>> _parametersList(dynamic raw) {
  if (raw is! List) {
    return const [];
  }
  final out = <Map<String, dynamic>>[];
  for (final p in raw) {
    if (p is Map<String, dynamic>) {
      out.add(p);
    } else if (p is Map) {
      out.add(Map<String, dynamic>.from(p));
    }
  }
  return out;
}

String _paramKey(Map<String, dynamic> p) {
  final name = p['name']?.toString() ?? '';
  final loc = p['in']?.toString().toLowerCase() ?? '';
  return '$name|$loc';
}

List<Map<String, dynamic>> _mergeParameters(
  List<Map<String, dynamic>> pathLevel,
  List<Map<String, dynamic>> opLevel,
) {
  final map = <String, Map<String, dynamic>>{};
  for (final p in pathLevel) {
    map[_paramKey(p)] = p;
  }
  for (final p in opLevel) {
    map[_paramKey(p)] = p;
  }
  final keys = map.keys.toList()..sort();
  return [for (final k in keys) map[k]!];
}

ParsedParameter _parseParameter(Map<String, dynamic> p, OpenApiSpecKind kind) {
  final name = p['name']?.toString() ?? '';
  final inLoc = p['in']?.toString().toLowerCase() ?? '';
  final required = p['required'] == true;
  final desc = p['description']?.toString();

  Map<String, dynamic>? schema;
  if (p['schema'] is Map) {
    final s = p['schema'];
    schema =
        s is Map<String, dynamic> ? s : Map<String, dynamic>.from(s as Map);
  } else if (kind == OpenApiSpecKind.swagger2 && p['type'] != null) {
    // Swagger 2：query/path 等参数上直接挂 type/format/enum
    schema = <String, dynamic>{
      'type': p['type'],
      if (p['format'] != null) 'format': p['format'],
      if (p['enum'] != null) 'enum': p['enum'],
      if (p['items'] != null) 'items': p['items'],
    };
  }

  String? ref;
  String? inlineType;
  List<String> enums = const [];
  if (schema != null) {
    final r = schema[r'$ref'];
    if (r is String) {
      ref = parseLocalSchemaRef(r);
    }
    inlineType = schema['type']?.toString();
    final en = schema['enum'];
    if (en is List) {
      enums = en.map((e) => e.toString()).toList(growable: false);
    }
  }

  return ParsedParameter(
    name: name,
    inLocation: inLoc,
    required: required,
    description: desc,
    schemaRef: ref,
    inlineType: inlineType,
    enumValues: enums,
  );
}

/// 从 JSON Schema 节点取出用于生成 Dart 类型的 `$ref`（含 `oneOf`/`anyOf`/`allOf` 内嵌套）。
///
/// 常见工具会写 `oneOf: [ { type: object }, { $ref: '#/components/schemas/X' } ]`，仅读顶层会丢 body。
String? _firstComponentSchemaRefInJsonSchema(Map<String, dynamic> sm) {
  final direct = sm[r'$ref'];
  if (direct is String) {
    return parseLocalSchemaRef(direct);
  }
  for (final key in ['oneOf', 'anyOf', 'allOf']) {
    final list = sm[key];
    if (list is! List) {
      continue;
    }
    for (final item in list) {
      if (item is! Map) {
        continue;
      }
      final nested = item is Map<String, dynamic>
          ? item
          : Map<String, dynamic>.from(item);
      final got = _firstComponentSchemaRefInJsonSchema(nested);
      if (got != null && got.isNotEmpty) {
        return got;
      }
    }
  }
  return null;
}

ParsedRequestBodySummary? _parseRequestBody(dynamic raw) {
  if (raw is! Map) {
    return null;
  }
  final m = raw is Map<String, dynamic> ? raw : Map<String, dynamic>.from(raw);
  final content = m['content'];
  if (content is! Map) {
    return ParsedRequestBodySummary(
      required: m['required'] == true,
      contentTypes: const [],
    );
  }
  final ctMap = content is Map<String, dynamic>
      ? content
      : Map<String, dynamic>.from(content);
  final types = ctMap.keys.map((k) => k.toString()).toList()..sort();
  String? jsonRef;
  final jsonMt = ctMap['application/json'];
  if (jsonMt is Map && jsonMt['schema'] is Map) {
    final sch = jsonMt['schema'];
    final sm = sch is Map<String, dynamic>
        ? sch
        : Map<String, dynamic>.from(sch as Map);
    jsonRef = _firstComponentSchemaRefInJsonSchema(sm);
  }
  return ParsedRequestBodySummary(
    required: m['required'] == true,
    contentTypes: types,
    jsonSchemaRef: jsonRef,
  );
}

Map<String, ParsedResponseSummary> _parseResponses(
  dynamic raw,
  OpenApiSpecKind kind,
) {
  if (raw is! Map) {
    return {};
  }
  final respMap =
      raw is Map<String, dynamic> ? raw : Map<String, dynamic>.from(raw);
  final out = <String, ParsedResponseSummary>{};
  for (final e in respMap.entries) {
    final code = e.key.toString();
    final v = e.value;
    if (v is! Map) {
      continue;
    }
    final rm = v is Map<String, dynamic> ? v : Map<String, dynamic>.from(v);
    final desc = rm['description']?.toString();
    List<String> cts = const [];
    String? jsonRef;
    String? legacyRef;

    if (kind != OpenApiSpecKind.swagger2 && rm['content'] is Map) {
      final content = rm['content'] as Map;
      final ctKeys =
          content.keys.map((k) => k.toString()).toList()..sort();
      cts = ctKeys;
      final jsonMt = content['application/json'];
      if (jsonMt is Map && jsonMt['schema'] is Map) {
        final sch = jsonMt['schema'];
        final sm = sch is Map<String, dynamic>
            ? sch
            : Map<String, dynamic>.from(sch as Map);
        jsonRef = _firstComponentSchemaRefInJsonSchema(sm);
      }
    } else if (rm['schema'] != null) {
      cts = const ['(legacy schema)'];
      final sch = rm['schema'];
      if (sch is Map) {
        final sm = sch is Map<String, dynamic>
            ? sch
            : Map<String, dynamic>.from(sch);
        legacyRef = _firstComponentSchemaRefInJsonSchema(sm);
      }
    }

    out[code] = ParsedResponseSummary(
      description: desc,
      contentTypes: cts,
      jsonSchemaRef: jsonRef,
      legacySchemaRef: legacyRef,
    );
  }
  final keys = out.keys.toList()..sort();
  return {for (final k in keys) k: out[k]!};
}

String? _pickSuccessJsonRef(Map<String, ParsedResponseSummary> responses) {
  const order = ['200', '201', '202', 'default'];
  for (final code in order) {
    final r = responses[code];
    if (r == null) {
      continue;
    }
    if (r.jsonSchemaRef != null && r.jsonSchemaRef!.isNotEmpty) {
      return r.jsonSchemaRef;
    }
    if (r.legacySchemaRef != null && r.legacySchemaRef!.isNotEmpty) {
      return r.legacySchemaRef;
    }
  }
  return null;
}
