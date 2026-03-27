/// 增强 OpenAPI 解析层（结构化 IR、本地 `$ref`、多文件浅合并、外部 ref 告警）。
///
/// 设计说明见 [docs/PARSE_LAYER.md](../../../../docs/PARSE_LAYER.md)。
library;

export 'openapi_document_parse.dart' show parseOpenApiDocument;
export 'openapi_parse_models.dart';
export 'parsed_openapi_document_json.dart';
export 'schema_ref.dart';
