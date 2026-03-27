import 'dart:io';

import 'package:contract_driven_interface_generation/contract_driven_interface_generation.dart';
import 'package:path/path.dart' as p;

import 'codegen_operation.dart';
import 'error_codes_collect.dart';
import 'grouping.dart';
import 'model_catalog.dart';
import 'name_utils.dart';
import 'render_api.dart';
import 'render_error_codes.dart';
import 'render_interface.dart';
import 'render_models.dart';

/// 一次生成写入的文件绝对路径列表。
final class NetRetrofitCodegenResult {
  const NetRetrofitCodegenResult({required this.writtenPaths});

  final List<String> writtenPaths;
}

/// 在 [outputRootAbsolute] 下按 [dirs] 写出 apis / interfaces / dto|vo（`net_retrofit_dio` 风格）。
///
/// [rawSpec] 与解析用 Map 一致，用于补全 multipart 等解析层未展开的细节。
Future<NetRetrofitCodegenResult> writeNetRetrofitCodegen({
  required ParsedOpenApiDocument document,
  required Map<String, dynamic> rawSpec,
  required String outputRootAbsolute,
  required CdigDirs dirs,
  required Map<String, String> tagToFilePrefix,
  String? netApiClient,
  bool unwrapSuccessData = true,
}) async {
  final reachable = reachableSchemaNames(document);
  final grouped = groupOperations(document);
  final groups = grouped.keys.toList()..sort();

  final codegenByGroup = <String, List<CodegenOperation>>{};
  for (final g in groups) {
    codegenByGroup[g] = buildCodegenOperations(
      operations: grouped[g]!,
      schemas: document.schemas,
      knownModels: reachable,
      spec: rawSpec,
      unwrapSuccessData: unwrapSuccessData,
    );
  }
  final allCodegen = <CodegenOperation>[
    for (final g in groups) ...codegenByGroup[g]!,
  ];

  final catalog = buildModelCatalog(
    reachable: reachable,
    document: document,
    allCodegenOps: allCodegen,
  );

  final written = <String>[];

  Future<void> writeUnderRoot(String relativePath, String content) async {
    final file = File(p.join(outputRootAbsolute, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    written.add(file.path);
  }

  for (final name in catalog.order) {
    final schema = document.schemas[name];
    if (schema == null) {
      continue;
    }
    final kind = catalog.kinds[name] ?? ModelKind.vo;
    final sub = modelSubdir(kind, dirs.dto, dirs.vo);
    final fileName = '${toSnake(refToDartName(name))}.dart';
    final content = renderModelDartFile(
      schemaName: name,
      schema: schema,
      kind: kind,
      kinds: catalog.kinds,
      catalogNames: reachable,
      dtoDir: dirs.dto,
      voDir: dirs.vo,
    );
    await writeUnderRoot(p.join(sub, fileName), content);
  }

  for (final g in groups) {
    final prefix = resolveFilePrefix(g, tagToFilePrefix);
    final groupOps = grouped[g]!;
    final codegenOps = codegenByGroup[g]!;

    final apiPath = p.join(dirs.apis, '${prefix}_api.dart');
    await writeUnderRoot(apiPath, renderApiDartFile(prefix, groupOps));

    final pathNames = pathConstNamesForGroup(groupOps);
    final ifacePath = p.join(dirs.interfaces, '${prefix}_interfaces.dart');
    await writeUnderRoot(
      ifacePath,
      renderInterfaceDartFile(
        prefix: prefix,
        codegenOps: codegenOps,
        pathConstNames: pathNames,
        apisDir: dirs.apis,
        interfacesDir: dirs.interfaces,
        dtoDir: dirs.dto,
        voDir: dirs.vo,
        catalog: catalog,
        netApiClient: netApiClient,
      ),
    );
  }

  if (dirs.errorCodes.isNotEmpty) {
    final collected = collectErrorCodes(document);
    final ecPath = p.join(dirs.errorCodes, 'openapi_error_codes.dart');
    await writeUnderRoot(
      ecPath,
      renderOpenApiErrorCodesDartFile(collected),
    );
  }

  return NetRetrofitCodegenResult(writtenPaths: written);
}
