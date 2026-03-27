import 'package:contract_driven_interface_generation/contract_driven_interface_generation.dart';

import 'codegen_operation.dart';

enum ModelKind { dto, vo }

/// 从 operations 可达的 schema + DTO/VO 分类（简化版 Go `BuildModelCatalog`）。
final class ModelCatalog {
  const ModelCatalog({
    required this.order,
    required this.kinds,
  });

  final List<String> order;
  final Map<String, ModelKind> kinds;
}

void _collectRefsFromSchema(
  Map<String, dynamic>? schema,
  void Function(String name) onRef,
) {
  if (schema == null) {
    return;
  }
  final props = schema['properties'];
  if (props is Map) {
    for (final v in props.values) {
      if (v is! Map) {
        continue;
      }
      final m = v is Map<String, dynamic> ? v : Map<String, dynamic>.from(v);
      final r = m[r'$ref'];
      if (r is String) {
        final n = parseLocalSchemaRef(r);
        if (n != null) {
          onRef(n);
        }
      }
      final items = m['items'];
      if (items is Map) {
        final im = items is Map<String, dynamic>
            ? items
            : Map<String, dynamic>.from(items);
        final ir = im[r'$ref'];
        if (ir is String) {
          final n = parseLocalSchemaRef(ir);
          if (n != null) {
            onRef(n);
          }
        }
      }
    }
  }
}

/// 从 [document.operations] 收集种子并经 properties 闭包，得到将生成模型的 schema 名集合。
Set<String> reachableSchemaNames(ParsedOpenApiDocument document) {
  final schemas = document.schemas;
  final seeds = <String>{};

  void seed(String? name) {
    final n = name?.trim();
    if (n == null || n.isEmpty || !schemas.containsKey(n)) {
      return;
    }
    seeds.add(n);
  }

  for (final op in document.operations) {
    seed(op.successJsonSchemaRef);
    seed(op.requestBody?.jsonSchemaRef);
    for (final p in op.parameters) {
      seed(p.schemaRef);
    }
  }

  final reachable = <String>{};
  void walk(String name, Set<String> stack) {
    if (!schemas.containsKey(name) || stack.contains(name)) {
      return;
    }
    stack.add(name);
    reachable.add(name);
    _collectRefsFromSchema(schemas[name], (ref) {
      if (schemas.containsKey(ref)) {
        walk(ref, stack);
      }
    });
    stack.remove(name);
  }

  for (final s in seeds.toList()..sort()) {
    walk(s, {});
  }
  return reachable;
}

ModelCatalog buildModelCatalog({
  required Set<String> reachable,
  required ParsedOpenApiDocument document,
  required List<CodegenOperation> allCodegenOps,
}) {
  final req = <String>{};
  final resp = <String>{};
  for (final op in allCodegenOps) {
    final b = op.requestBodyRef?.trim();
    if (b != null && b.isNotEmpty) {
      req.add(b);
    }
    final r = op.responseRefForImport?.trim();
    if (r != null && r.isNotEmpty) {
      resp.add(r);
    }
  }

  final order = topologicalSchemaOrder(reachable, document.schemas);
  final kinds = <String, ModelKind>{};
  for (final n in order) {
    final inReq = req.contains(n);
    final inResp = resp.contains(n);
    if (inReq && !inResp) {
      kinds[n] = ModelKind.dto;
    } else if (inResp && !inReq) {
      kinds[n] = ModelKind.vo;
    } else if (inReq && inResp) {
      kinds[n] = ModelKind.dto;
    } else {
      kinds[n] = ModelKind.vo;
    }
  }
  return ModelCatalog(order: order, kinds: kinds);
}

/// 依赖拓扑：仅含 [names] 内的边；无法解环时按字典序强行插入。
List<String> topologicalSchemaOrder(
  Set<String> names,
  Map<String, Map<String, dynamic>> schemas,
) {
  final deps = <String, Set<String>>{};
  for (final n in names) {
    final d = <String>{};
    _collectRefsFromSchema(schemas[n], (ref) {
      if (names.contains(ref)) {
        d.add(ref);
      }
    });
    deps[n] = d;
  }
  final result = <String>[];
  final remaining = names.toList()..sort();
  while (remaining.isNotEmpty) {
    String? pick;
    for (final n in remaining) {
      final ok = deps[n]!.every(result.contains);
      if (ok) {
        pick = n;
        break;
      }
    }
    pick ??= remaining.first;
    remaining.remove(pick);
    result.add(pick);
  }
  return result;
}

String modelSubdir(ModelKind k, String dtoDir, String voDir) =>
    k == ModelKind.dto ? dtoDir : voDir;
