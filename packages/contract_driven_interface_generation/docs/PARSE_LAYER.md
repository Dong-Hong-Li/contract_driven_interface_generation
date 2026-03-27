# Dart 增强解析层（`lib/src/openapi/parse`）

本文档说明：在 **`contract_driven_interface_generation` 段配置**（`output_root`、`dirs`、`tag_to_file_prefix`、`open_api_files`、可选 `openapi.filters`）下，为何需要单独一层解析、相对 Go 版 `cdig` 补了哪些能力，以及如何接入。

## 1. 配置（与生成布局对齐）

段根字段：

- **`open_api_files`**：OpenAPI 文件列表（必填；路径相对**配置文件所在目录**）
- **`output_root`**：生成输出根目录（相对配置文件目录）
- **`dirs`**：`apis` / `interfaces` / `dto` / `vo`（可省略，默认与 Go `cdig` 一致）
- **`tag_to_file_prefix`**：可选 map
- **`openapi.filters`**：可选，键名与 Go `matchesFilters` 一致

解析层不新增上述键以外的「魔法字段」；输入为合并后的 `Map<String, dynamic>`，过滤语义与 `openapi_path_filter.dart` 一致。

## 2. Go `cdig` 解析层缺什么（摘要）


| 能力                                                   | Go `internal/openapi`                | 本 Dart 增强层                                                               |
| ---------------------------------------------------- | ------------------------------------ | ------------------------------------------------------------------------ |
| 规范版本与 `info`                                         | 反序列化时未建模，生成逻辑不依赖                     | 显式 `ParsedOpenApiInfo` + `openapi`/`swagger` 原始串                         |
| `servers` / Swagger2 `host`、`basePath`、`schemes`     | 未读                                   | 结构化列出（便于后续拼接 baseUrl）                                                    |
| `components.securitySchemes` / `securityDefinitions` | 未读                                   | 收集为 `Map`（原始子树，便于审计）                                                     |
| 路径级 `parameters` 与 operation 合并                      | 仅用 operation 上字段                     | **Path Item + Operation** 按 `(name, in)` 合并，operation 覆盖 path            |
| 每条 operation 的完整元数据                                  | `GroupedOperation` 面向 NetApi         | `ParsedOperation`：参数列表、requestBody 多 content-type、responses 键、**枚举字段**摘要 |
| Schema 注册表                                           | `components.schemas` + `definitions` | 同上，并提供 **内部 `$ref` 解析**（`#/components/schemas/`、`#/definitions/`）        |
| 外部 / 非组件 `$ref`                                      | 忽略                                   | **扫描并记入 `warnings`**（不拉取外链）                                              |
| 多文件                                                  | `LoadAndMerge`                       | `mergeOpenApiDocuments`（paths + schemas 浅合并，后者覆盖）                        |


本层**仍不**实现：外链拉取、JSON Schema 全集、`discriminator` 代码生成、与 `swagger_parser` 的 `Universal`* IR 对齐。目标是：**在 cdig 同配置下，多读出规范里已有但未利用的结构**，供后续生成器或报告使用。

## 3. 入口 API

- `parseOpenApiDocument(spec, filters: ...)` → `ParsedOpenApiDocument`
- `mergeOpenApiDocuments(specs)` → 合并后的 `Map`（再交给 `parseOpenApiDocument`）
- `resolveLocalSchemaRef(registry, ref)` → 本地 schema 子树或 `null`
- `collectExternalRefWarnings(spec)` → 文档级外部 `$ref` 提示列表

导出见 `lib/src/openapi/openapi.dart`。

## 4. 与 `OpenApiCaseSample` 的关系

`OpenApiCaseSample` 继续承担「轻量 paths 摘要」；增强层面向 **需要结构化遍历** 的场景。可选在业务侧用 `ParsedOpenApiDocument` 生成更丰富的报告，而不修改现有案例类的契约。

## 5. 推荐阅读顺序

1. `openapi_parse_models.dart`（IR 形状）
2. `openapi_document_parse.dart`（主流程）
3. `schema_ref.dart`（合并与 `$ref`）
4. `test/openapi_parse_layer_test.dart`

