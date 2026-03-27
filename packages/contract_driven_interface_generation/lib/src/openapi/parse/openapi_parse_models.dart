/// 增强解析层的结构化结果（与 Go `cdig` 的 `Spec` / `GroupedOperation` 相比字段更全）。
library;

/// OpenAPI 2 / 3 粗分类（不校验 patch 级别）。
enum OpenApiSpecKind { openApi3, swagger2, unknown }

final class ParsedOpenApiInfo {
  const ParsedOpenApiInfo({
    this.title,
    this.version,
    this.description,
  });

  final String? title;
  final String? version;
  final String? description;
}

final class ParsedServer {
  const ParsedServer({this.url, this.description});

  final String? url;
  final String? description;
}

/// RequestBody 摘要（多 content-type、JSON `$ref`）。
final class ParsedRequestBodySummary {
  const ParsedRequestBodySummary({
    required this.required,
    required this.contentTypes,
    this.jsonSchemaRef,
  });

  final bool required;
  final List<String> contentTypes;
  final String? jsonSchemaRef;
}

/// 单条 HTTP 响应摘要。
final class ParsedResponseSummary {
  const ParsedResponseSummary({
    this.description,
    required this.contentTypes,
    this.jsonSchemaRef,
    this.legacySchemaRef,
  });

  final String? description;
  final List<String> contentTypes;

  /// OpenAPI 3：`content['application/json'].schema.$ref`
  final String? jsonSchemaRef;

  /// Swagger 2：`response.schema.$ref`
  final String? legacySchemaRef;
}

/// 参数（path/query/header/cookie/body）。
final class ParsedParameter {
  const ParsedParameter({
    required this.name,
    required this.inLocation,
    required this.required,
    this.description,
    this.schemaRef,
    this.inlineType,
    this.enumValues = const [],
  });

  final String name;

  /// 对应 OpenAPI `in` 字段（小写）。
  final String inLocation;
  final bool required;
  final String? description;

  /// 本地 components/definitions 解析出的 schema 名。
  final String? schemaRef;
  final String? inlineType;
  final List<String> enumValues;
}

/// 单条 operation（已应用 filters）。
final class ParsedOperation {
  const ParsedOperation({
    required this.path,
    required this.method,
    this.operationId,
    this.summary,
    this.description,
    this.tags = const [],
    this.parameters = const [],
    this.requestBody,
    this.responsesByCode = const {},
    this.successJsonSchemaRef,
    this.deprecated = false,
  });

  final String path;
  final String method;
  final String? operationId;
  final String? summary;
  final String? description;
  final List<String> tags;
  final List<ParsedParameter> parameters;
  final ParsedRequestBodySummary? requestBody;
  final Map<String, ParsedResponseSummary> responsesByCode;

  /// 自 200/201/202 的 `application/json` 或 Swagger2 schema 提取的首个本地 `$ref`（若有）。
  final String? successJsonSchemaRef;
  final bool deprecated;
}

/// 增强解析结果。
final class ParsedOpenApiDocument {
  const ParsedOpenApiDocument({
    required this.rawVersionField,
    required this.kind,
    this.info,
    this.servers = const [],
    this.swaggerHost,
    this.swaggerBasePath,
    this.swaggerSchemes = const [],
    this.securitySchemes = const {},
    required this.schemas,
    required this.operations,
    required this.warnings,
    required this.filteredPathCount,
  });

  /// `openapi:` 或 `swagger:` 的原始标量字符串。
  final String rawVersionField;
  final OpenApiSpecKind kind;
  final ParsedOpenApiInfo? info;
  final List<ParsedServer> servers;

  final String? swaggerHost;
  final String? swaggerBasePath;
  final List<String> swaggerSchemes;

  /// `components.securitySchemes` 或 `securityDefinitions` 的原始 map（可能为空）。
  final Map<String, dynamic> securitySchemes;

  final Map<String, Map<String, dynamic>> schemas;
  final List<ParsedOperation> operations;

  /// 如外部 `$ref` 等。
  final List<String> warnings;

  /// 过滤后至少命中一条 operation 的 path 数量。
  final int filteredPathCount;
}
