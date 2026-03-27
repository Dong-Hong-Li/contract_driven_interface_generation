import '../config/openapi_filters_config.dart';
import 'openapi_path_filter.dart';
import 'parse/openapi_document_parse.dart';
import 'parse/openapi_parse_models.dart';

/// 解析 OpenAPI Map 后生成的**可读案例摘要**（轻量 paths + [parseOpenApiDocument] 结构化摘要）。
final class OpenApiCaseSample {
  const OpenApiCaseSample({
    required this.schemaVersion,
    this.apiTitle,
    this.apiVersion,
    this.apiDescriptionPreview,
    required this.pathCount,
    required this.pathSamples,
    required this.parsed,
    this.filtersApplied = OpenApiFiltersConfig.empty,
  });

  /// 最多列出的 path 示例条数（全量仍见 [pathCount]）。
  static const int pathSampleLimit = 50;

  /// 报告中列出的 operation 明细上限。
  static const int operationDetailLimit = 60;

  /// 规范版本
  final String schemaVersion;

  /// 规范标题
  final String? apiTitle;

  /// 规范版本
  final String? apiVersion;

  /// info.description 前若干字（无则 null）
  final String? apiDescriptionPreview;

  /// 路径数量
  final int pathCount;

  /// 路径样本
  final List<String> pathSamples;

  /// 与 [filtersApplied] 一致的增强解析结果。
  final ParsedOpenApiDocument parsed;

  /// 生成报告时使用的过滤配置（仅用于展示；空表示未启用）。
  final OpenApiFiltersConfig filtersApplied;

  factory OpenApiCaseSample.fromSpec(
    Map<String, dynamic> spec, {
    OpenApiFiltersConfig filters = OpenApiFiltersConfig.empty,
  }) {
    final ver =
        spec['openapi']?.toString() ?? spec['swagger']?.toString() ?? '?';
    final info = spec['info'];
    String? title;
    String? apiVer;
    String? descPreview;
    if (info is Map) {
      title = info['title']?.toString();
      apiVer = info['version']?.toString();
      final desc = info['description']?.toString().trim();
      if (desc != null && desc.isNotEmpty) {
        descPreview = desc.length > 280 ? '${desc.substring(0, 280)}…' : desc;
      }
    }
    final pathsRaw = spec['paths'];
    final keys = <String>[];
    if (pathsRaw is Map<String, dynamic>) {
      keys.addAll(filterPathKeys(pathsRaw, filters));
    } else if (pathsRaw is Map) {
      keys.addAll(
        filterPathKeys(Map<String, dynamic>.from(pathsRaw), filters),
      );
    }
    final samples = keys.take(pathSampleLimit).toList(growable: false);
    final parsed = parseOpenApiDocument(spec, filters: filters);
    return OpenApiCaseSample(
      schemaVersion: ver,
      apiTitle: title,
      apiVersion: apiVer,
      apiDescriptionPreview: descPreview,
      pathCount: keys.length,
      pathSamples: samples,
      parsed: parsed,
      filtersApplied: filters,
    );
  }

  /// 写入 `output_root` 等目录用的文本案例。
  String toReport() {
    final buf = StringBuffer()
      ..writeln('# OpenAPI 解析案例（自动生成）')
      ..writeln()
      ..writeln('- 规范字段: openapi/swagger = `$schemaVersion`')
      ..writeln('- info.title: ${apiTitle ?? '(无)'}')
      ..writeln('- info.version: ${apiVersion ?? '(无)'}');
    if (apiDescriptionPreview != null) {
      buf.writeln('- info.description（摘录）:');
      for (final line in apiDescriptionPreview!.split('\n')) {
        buf.writeln('    $line');
      }
    }
    buf.writeln(
      filtersApplied.isEmpty
          ? '- paths 数量: $pathCount'
          : '- paths 数量（过滤后）: $pathCount',
    );
    if (!filtersApplied.isEmpty) {
      buf
        ..writeln(
            '- 过滤: include_path_prefixes=${filtersApplied.includePathPrefixes}')
        ..writeln(
            '        exclude_path_prefixes=${filtersApplied.excludePathPrefixes}')
        ..writeln('        include_tags=${filtersApplied.includeTags}')
        ..writeln('        exclude_tags=${filtersApplied.excludeTags}');
    }
    buf.writeln();
    if (pathSamples.isEmpty) {
      buf.writeln('（无 paths 条目）');
    } else {
      final more = pathCount > pathSamples.length
          ? '（共 $pathCount 条，下列 ${pathSamples.length} 条）'
          : '';
      buf.writeln('paths 示例 $more:');
      for (final k in pathSamples) {
        buf.writeln('  - $k');
      }
    }

    _appendParseSection(buf);
    return buf.toString();
  }

  void _appendParseSection(StringBuffer buf) {
    final d = parsed;
    buf
      ..writeln()
      ..writeln('---')
      ..writeln('## 增强解析摘要')
      ..writeln('- 规范类型: ${_kindLabel(d.kind)}')
      ..writeln('- 过滤后 path 数: ${d.filteredPathCount}')
      ..writeln('- operations 数: ${d.operations.length}')
      ..writeln('- components/definitions 中 schema 数: ${d.schemas.length}');

    if (d.servers.isNotEmpty) {
      buf.writeln('- servers:');
      for (final s in d.servers) {
        final u = s.url ?? '(无 url)';
        final desc = s.description;
        buf.writeln(
          desc != null && desc.isNotEmpty ? '  - $u  ($desc)' : '  - $u',
        );
      }
    }
    if (d.swaggerHost != null && d.swaggerHost!.trim().isNotEmpty) {
      final bp = d.swaggerBasePath;
      buf.write('- Swagger2 host: ${d.swaggerHost}');
      if (bp != null && bp.trim().isNotEmpty) {
        buf.write('  basePath: $bp');
      }
      buf.writeln();
      if (d.swaggerSchemes.isNotEmpty) {
        buf.writeln('  schemes: ${d.swaggerSchemes.join(', ')}');
      }
    }

    if (d.securitySchemes.isNotEmpty) {
      final names = d.securitySchemes.keys.map((e) => e.toString()).toList()
        ..sort();
      buf.writeln('- securitySchemes / securityDefinitions: ${names.length} 个');
      for (final n in names.take(40)) {
        buf.writeln('  - $n');
      }
      if (names.length > 40) {
        buf.writeln('  … 另有 ${names.length - 40} 个未列出');
      }
    }

    final byMethod = <String, int>{};
    final tagHits = <String, int>{};
    for (final op in d.operations) {
      byMethod[op.method] = (byMethod[op.method] ?? 0) + 1;
      for (final t in op.tags) {
        tagHits[t] = (tagHits[t] ?? 0) + 1;
      }
    }
    if (byMethod.isNotEmpty) {
      buf.writeln('- HTTP 方法统计:');
      for (final m in byMethod.keys.toList()..sort()) {
        buf.writeln('  - $m: ${byMethod[m]}');
      }
    }
    if (tagHits.isNotEmpty) {
      final top = tagHits.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      buf.writeln('- tags（按 operation 出现次数，至多 25 个）:');
      for (final e in top.take(25)) {
        buf.writeln('  - ${e.key}: ${e.value}');
      }
    }

    if (d.warnings.isNotEmpty) {
      buf.writeln('- 外部 / 非本地 `#/` \$ref 告警（${d.warnings.length} 条，至多列 20）:');
      for (final w in d.warnings.take(20)) {
        buf.writeln('  - $w');
      }
      if (d.warnings.length > 20) {
        buf.writeln('  … 另有 ${d.warnings.length - 20} 条');
      }
    }

    buf.writeln();
    buf.writeln('### Operation 明细（至多 $operationDetailLimit 条）');
    if (d.operations.isEmpty) {
      buf.writeln('（无）');
    } else {
      for (var i = 0;
          i < d.operations.length && i < operationDetailLimit;
          i++) {
        final op = d.operations[i];
        final id = op.operationId?.trim();
        final idStr = (id == null || id.isEmpty) ? '—' : id;
        final tags = op.tags.isEmpty ? '—' : op.tags.join(', ');
        final succ = op.successJsonSchemaRef ?? '—';
        final req = _requestBodyReportLine(op.requestBody);
        final dep = op.deprecated ? ' deprecated' : '';
        buf.writeln(
          '${op.method.toUpperCase().padRight(7)} ${op.path}$dep',
        );
        buf.writeln(
          '    operationId: $idStr  |  tags: $tags',
        );
        buf.writeln(
          '    成功响应 JSON schema: $succ  |  请求体 JSON schema: $req',
        );
      }
      if (d.operations.length > operationDetailLimit) {
        buf.writeln(
          '… 另有 ${d.operations.length - operationDetailLimit} 条未列出',
        );
      }
    }
  }

  /// 请求体在报告中的展示：优先 `$ref` 名；仅有内联 JSON 时避免与「无 body」混用 `—`。
  static String _requestBodyReportLine(ParsedRequestBodySummary? rb) {
    if (rb == null) return '—';
    final ref = rb.jsonSchemaRef?.trim();
    if (ref != null && ref.isNotEmpty) return ref;
    if (rb.contentTypes.contains('application/json')) {
      return r'application/json（内联/无 $ref）';
    }
    if (rb.contentTypes.isNotEmpty) {
      return rb.contentTypes.join(', ');
    }
    return '—';
  }

  static String _kindLabel(OpenApiSpecKind k) {
    return switch (k) {
      OpenApiSpecKind.openApi3 => 'OpenAPI 3.x',
      OpenApiSpecKind.swagger2 => 'Swagger 2.0',
      OpenApiSpecKind.unknown => '未知',
    };
  }
}
