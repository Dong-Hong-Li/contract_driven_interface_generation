import 'package:contract_driven_interface_generation/contract_driven_interface_generation.dart';

import 'name_utils.dart';

/// multipart 字段（对齐 Go `FormPart`）。
final class FormPart {
  const FormPart({required this.name, required this.isFile});

  final String name;
  final bool isFile;
}

/// 单条 operation 的生成视图（由 [ParsedOperation] + 规范 Map 推导）。
final class CodegenOperation {
  const CodegenOperation({
    required this.source,
    required this.methodName,
    required this.httpAnno,
    required this.returnType,
    required this.hasResponseBody,
    required this.streamResponse,
    required this.formData,
    required this.formParts,
    this.dataPath,
    required this.responseRefForImport,
    required this.requestBodyRef,
    required this.requestBodyRequired,
    required this.paramDecls,
  });

  final ParsedOperation source;
  final String methodName;
  final String httpAnno;
  final String returnType;
  final bool hasResponseBody;
  final bool streamResponse;
  final bool formData;
  final List<FormPart> formParts;
  final String? dataPath;

  /// 用于收集 model import（内层 VO/DTO 名，非包装类名）。
  final String? responseRefForImport;
  final String? requestBodyRef;
  final bool requestBodyRequired;
  final List<String> paramDecls;
}

bool _isWrapperResponseRef(String ref) {
  final s = ref.trim().toLowerCase();
  if (s.isEmpty) {
    return false;
  }
  return s.endsWith('apiresponse') ||
      s == 'baseresponse' ||
      s == 'response';
}

(String? dataPath, String? innerRef, bool isList) _unwrapWrapperResponse(
  String? topRef,
  Map<String, Map<String, dynamic>> schemas,
) {
  if (topRef == null || topRef.isEmpty) {
    return (null, null, false);
  }
  final sch = schemas[topRef];
  if (sch == null) {
    return (null, topRef, false);
  }
  final props = sch['properties'];
  if (props is! Map) {
    return (null, topRef, false);
  }
  for (final key in ['data', 'result']) {
    final prop = props[key];
    if (prop is! Map) {
      continue;
    }
    final r = prop[r'$ref'];
    if (r is String) {
      final inner = parseLocalSchemaRef(r);
      if (inner != null) {
        return (key, inner, false);
      }
    }
    final items = prop['items'];
    if (items is Map) {
      final ir = items[r'$ref'];
      if (ir is String) {
        final inner = parseLocalSchemaRef(ir);
        if (inner != null) {
          return (key, inner, true);
        }
      }
    }
  }
  return (null, topRef, false);
}

/// 包装类仅有 `data`/`result` 键但无 `$ref` 时仍生成 @DataPath（对齐 Go `wrapperDataPath`）。
String? _wrapperDataPathOnly(String? topRef, Map<String, Map<String, dynamic>> schemas) {
  if (topRef == null || topRef.isEmpty) {
    return null;
  }
  final sch = schemas[topRef];
  final props = sch?['properties'];
  if (props is! Map) {
    return null;
  }
  for (final key in ['data', 'result']) {
    if (props.containsKey(key)) {
      return key;
    }
  }
  return null;
}

bool _inferStream(ParsedOperation op) {
  for (final code in ['200', '201', '202', 'default']) {
    final r = op.responsesByCode[code];
    if (r?.contentTypes.contains('text/event-stream') == true) {
      return true;
    }
  }
  return false;
}

bool _inferHasJsonBody(ParsedOperation op) {
  if (op.successJsonSchemaRef != null && op.successJsonSchemaRef!.isNotEmpty) {
    return true;
  }
  for (final code in ['200', '201', '202']) {
    final r = op.responsesByCode[code];
    if (r == null) {
      continue;
    }
    if (r.jsonSchemaRef != null || r.legacySchemaRef != null) {
      return true;
    }
  }
  return false;
}

List<FormPart> formPartsFromSpec(
  Map<String, dynamic> spec,
  String path,
  String method,
) {
  final paths = spec['paths'];
  if (paths is! Map) {
    return const [];
  }
  final item = paths[path];
  if (item is! Map) {
    return const [];
  }
  final op = item[method.toLowerCase()];
  if (op is! Map) {
    return const [];
  }
  final rb = op['requestBody'];
  if (rb is! Map) {
    return const [];
  }
  final content = rb['content'];
  if (content is! Map) {
    return const [];
  }
  final mt = content['multipart/form-data'];
  if (mt is! Map) {
    return const [];
  }
  final sch = mt['schema'];
  if (sch is! Map) {
    return const [];
  }
  final props = sch['properties'];
  if (props is! Map) {
    return const [];
  }
  final names = props.keys.map((e) => e.toString()).toList()..sort();
  final out = <FormPart>[];
  for (final n in names) {
    final p = props[n];
    if (p is! Map) {
      continue;
    }
    final fmt = p['format']?.toString().toLowerCase().trim() ?? '';
    out.add(FormPart(name: n, isFile: fmt == 'binary'));
  }
  return out;
}

bool _hasFormData(ParsedOperation op, Map<String, dynamic> spec) {
  if (op.requestBody?.contentTypes.contains('multipart/form-data') == true) {
    return true;
  }
  return formPartsFromSpec(spec, op.path, op.method).isNotEmpty;
}

String _defaultMethodName(ParsedOperation op) {
  final id = op.operationId?.trim();
  if (id != null && id.isNotEmpty) {
    return toCamelIdentifier(id);
  }
  return toCamelIdentifier('${op.method}_${pathToConstName(op.path)}');
}

String _resolveReturnType({
  required bool stream,
  required bool hasBody,
  required String? innerRef,
  required bool isList,
  required Set<String> knownModels,
  required bool unwrapSuccessData,
}) {
  if (stream) {
    return 'Stream<String>';
  }
  if (!hasBody) {
    return 'bool';
  }
  final ref = innerRef?.trim();
  if (ref == null || ref.isEmpty) {
    return 'Map<String, dynamic>?';
  }
  // 仅「剥 data」模式把 *ApiResponse 等当作 Map；保留外壳时返回具体包装类型以便读 code/message。
  if (unwrapSuccessData && _isWrapperResponseRef(ref)) {
    return 'Map<String, dynamic>?';
  }
  if (knownModels.contains(ref)) {
    final dart = toPascal(refToDartName(ref));
    if (isList) {
      return 'List<$dart>?';
    }
    return '$dart?';
  }
  return 'Map<String, dynamic>?';
}

String _paramTypeFromParsed(ParsedParameter p) {
  if (p.schemaRef != null && p.schemaRef!.isNotEmpty) {
    final t = '${toPascal(refToDartName(p.schemaRef!))}${p.required ? '' : '?'}';
    return t;
  }
  switch (p.inlineType?.toLowerCase()) {
    case 'string':
      return p.required ? 'String' : 'String?';
    case 'integer':
      return p.required ? 'int' : 'int?';
    case 'number':
      return p.required ? 'double' : 'double?';
    case 'boolean':
      return p.required ? 'bool' : 'bool?';
    case 'array':
      return p.required ? 'List<dynamic>' : 'List<dynamic>?';
    default:
      if (p.enumValues.isNotEmpty) {
        return p.required ? 'String' : 'String?';
      }
      return p.required ? 'dynamic' : 'dynamic?';
  }
}

String _annotationForIn(String inLoc, String paramName) {
  switch (inLoc.toLowerCase()) {
    case 'path':
      return "@Path('$paramName')";
    case 'header':
      return "@Header('$paramName')";
    case 'query':
      return "@QueryKey('$paramName')";
    default:
      return "@QueryKey('$paramName')";
  }
}

List<String> _buildParamDecls(
  ParsedOperation op,
  bool formData,
  List<FormPart> parts,
  String? bodyType,
  bool bodyRequired,
) {
  final decls = <String>[];
  if (formData) {
    for (final fp in parts) {
      final dartName = jsonKeyToDartName(fp.name);
      final typ = fp.isFile ? 'File' : 'String';
      decls.add("@Part('${fp.name}') $typ $dartName");
    }
    return decls;
  }
  for (final p in op.parameters) {
    final loc = p.inLocation.toLowerCase();
    if (loc == 'body') {
      continue;
    }
    final name = p.name.trim().isEmpty ? 'value' : p.name.trim();
    decls.add(
      '${_annotationForIn(loc, name)} ${_paramTypeFromParsed(p)} ${jsonKeyToDartName(name)}',
    );
  }
  if (bodyType != null) {
    final suffix = bodyRequired && !bodyType.endsWith('?') ? '' : '?';
    final t = bodyType.endsWith('?') ? bodyType : '$bodyType$suffix';
    decls.add('@Body() $t body');
  }
  return decls;
}

String? _resolveBodyType(
  ParsedOperation op,
  Set<String> knownModels,
) {
  final rb = op.requestBody;
  final jsonRef = rb?.jsonSchemaRef?.trim();
  if (jsonRef != null && jsonRef.isNotEmpty) {
    if (knownModels.contains(jsonRef)) {
      return toPascal(refToDartName(jsonRef));
    }
    return 'Map<String, dynamic>';
  }
  // 仅有内联 schema（如 oneOf 里无 $ref）时仍应有 JSON body 参数
  if (rb != null &&
      rb.contentTypes.contains('application/json') &&
      jsonRef == null) {
    return 'Map<String, dynamic>';
  }
  for (final p in op.parameters) {
    if (p.inLocation.toLowerCase() != 'body') {
      continue;
    }
    final sr = p.schemaRef?.trim();
    if (sr != null && sr.isNotEmpty && knownModels.contains(sr)) {
      return toPascal(refToDartName(sr));
    }
    return 'Map<String, dynamic>';
  }
  return null;
}

bool _bodyRequired(ParsedOperation op) {
  if (op.requestBody != null) {
    return op.requestBody!.required;
  }
  for (final p in op.parameters) {
    if (p.inLocation.toLowerCase() == 'body') {
      return p.required;
    }
  }
  return false;
}

/// 由文档与（可选）原始规范构造可生成列表；[knownModels] 为将生成 Dart 文件的 schema 名集合。
///
/// [unwrapSuccessData] 为 `false` 时不生成 `@DataPath`，返回类型为 200 的完整 schema（如 `XxxApiResponse?`）。
List<CodegenOperation> buildCodegenOperations({
  required List<ParsedOperation> operations,
  required Map<String, Map<String, dynamic>> schemas,
  required Set<String> knownModels,
  required Map<String, dynamic> spec,
  bool unwrapSuccessData = true,
}) {
  final seen = <String, int>{};
  final out = <CodegenOperation>[];
  for (final op in operations) {
    var name = _defaultMethodName(op);
    final c = (seen[name] ?? 0) + 1;
    seen[name] = c;
    if (c > 1) {
      name = '$name$c';
    }

    final stream = _inferStream(op);
    final formData = _hasFormData(op, spec);
    final parts = formData ? formPartsFromSpec(spec, op.path, op.method) : const <FormPart>[];

    final topSuccess = op.successJsonSchemaRef;
    var dataPath = unwrapSuccessData ? _wrapperDataPathOnly(topSuccess, schemas) : null;
    var inner = topSuccess;
    var isList = false;
    if (unwrapSuccessData && topSuccess != null && topSuccess.isNotEmpty) {
      final u = _unwrapWrapperResponse(topSuccess, schemas);
      if (u.$1 != null) {
        dataPath = u.$1;
        inner = u.$2;
        isList = u.$3;
      } else {
        inner = u.$2;
        isList = u.$3;
      }
    }

    final hasBody = stream || _inferHasJsonBody(op);
    final returnType = _resolveReturnType(
      stream: stream,
      hasBody: hasBody,
      innerRef: inner,
      isList: isList,
      knownModels: knownModels,
      unwrapSuccessData: unwrapSuccessData,
    );

    String? importRef = inner?.trim();
    if (unwrapSuccessData &&
        importRef != null &&
        _isWrapperResponseRef(importRef)) {
      importRef = null;
    }

    final bodyType = formData ? null : _resolveBodyType(op, knownModels);
    final rbRef = op.requestBody?.jsonSchemaRef?.trim();
    String? reqRef = rbRef;
    if (reqRef == null || reqRef.isEmpty) {
      for (final p in op.parameters) {
        if (p.inLocation.toLowerCase() == 'body') {
          reqRef = p.schemaRef?.trim();
          break;
        }
      }
    }

    final paramDecls = _buildParamDecls(
      op,
      formData,
      parts,
      bodyType,
      _bodyRequired(op),
    );

    out.add(
      CodegenOperation(
        source: op,
        methodName: name,
        httpAnno: httpAnnotation(op.method),
        returnType: returnType,
        hasResponseBody: hasBody,
        streamResponse: stream,
        formData: formData,
        formParts: parts,
        dataPath: stream
            ? null
            : (dataPath?.isNotEmpty == true ? dataPath : null),
        responseRefForImport: importRef,
        requestBodyRef: reqRef,
        requestBodyRequired: _bodyRequired(op),
        paramDecls: paramDecls,
      ),
    );
  }
  return out;
}
