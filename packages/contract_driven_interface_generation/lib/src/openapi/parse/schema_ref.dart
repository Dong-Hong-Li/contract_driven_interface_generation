/// 本地 `$ref`、多文档浅合并（对齐 Go `LoadAndMerge` 语义）。
library;

/// 识别 `#/components/schemas/Name` 与 `#/definitions/Name`，返回 `Name`。
String? parseLocalSchemaRef(String? ref) {
  if (ref == null) {
    return null;
  }
  final s = ref.trim();
  const p1 = '#/components/schemas/';
  const p2 = '#/definitions/';
  if (s.startsWith(p1)) {
    final name = s.substring(p1.length).trim();
    return name.isEmpty ? null : name;
  }
  if (s.startsWith(p2)) {
    final name = s.substring(p2.length).trim();
    return name.isEmpty ? null : name;
  }
  return null;
}

bool _isExternalRef(String ref) {
  final s = ref.trim();
  if (s.isEmpty) {
    return false;
  }
  if (s.startsWith('#/')) {
    return false;
  }
  return true;
}

/// 合并多份规范：`paths` 按 path/method 合并（后者覆盖），`components.schemas` 与 `definitions` 同名后者覆盖。
Map<String, dynamic> mergeOpenApiDocuments(List<Map<String, dynamic>> specs) {
  if (specs.isEmpty) {
    return {};
  }
  final merged = <String, dynamic>{};

  void mergeTopLevel(String key, dynamic value) {
    if (value == null) {
      return;
    }
    merged[key] = value;
  }

  for (final spec in specs) {
    for (final e in spec.entries) {
      if (e.key == 'paths') {
        final dst = (merged['paths'] is Map<String, dynamic>)
            ? Map<String, dynamic>.from(merged['paths']! as Map)
            : <String, dynamic>{};
        final src = e.value;
        if (src is Map) {
          for (final pe in src.entries) {
            final pathKey = pe.key.toString();
            final pathItem = pe.value;
            if (pathItem is! Map) {
              continue;
            }
            final itemMap = pathItem is Map<String, dynamic>
                ? pathItem
                : Map<String, dynamic>.from(pathItem);
            final existing = (dst[pathKey] is Map<String, dynamic>)
                ? Map<String, dynamic>.from(dst[pathKey]! as Map)
                : <String, dynamic>{};
            for (final me in itemMap.entries) {
              existing[me.key.toString()] = me.value;
            }
            dst[pathKey] = existing;
          }
        }
        merged['paths'] = dst;
        continue;
      }
      if (e.key == 'components' && e.value is Map) {
        final comp = e.value as Map;
        final schemas = comp['schemas'];
        if (schemas is! Map) {
          mergeTopLevel('components', e.value);
          continue;
        }
        final dstRoot = (merged['components'] is Map<String, dynamic>)
            ? Map<String, dynamic>.from(merged['components']! as Map)
            : <String, dynamic>{};
        final dstSchemas = (dstRoot['schemas'] is Map<String, dynamic>)
            ? Map<String, dynamic>.from(dstRoot['schemas']! as Map)
            : <String, dynamic>{};
        for (final se in schemas.entries) {
          dstSchemas[se.key.toString()] = se.value;
        }
        dstRoot['schemas'] = dstSchemas;
        merged['components'] = dstRoot;
        continue;
      }
      if (e.key == 'definitions' && e.value is Map) {
        final srcDef = e.value as Map;
        final dstDef = (merged['definitions'] is Map<String, dynamic>)
            ? Map<String, dynamic>.from(merged['definitions']! as Map)
            : <String, dynamic>{};
        for (final de in srcDef.entries) {
          dstDef[de.key.toString()] = de.value;
        }
        merged['definitions'] = dstDef;
        continue;
      }
      mergeTopLevel(e.key, e.value);
    }
  }
  return merged;
}

/// 从规范构建 `schemaName -> schema对象`（浅拷贝引用，不解析 `$ref`）。
Map<String, Map<String, dynamic>> buildSchemaRegistry(Map<String, dynamic> spec) {
  final out = <String, Map<String, dynamic>>{};
  final comp = spec['components'];
  if (comp is Map && comp['schemas'] is Map) {
    final schemas = comp['schemas'] as Map;
    for (final e in schemas.entries) {
      final v = e.value;
      if (v is Map<String, dynamic>) {
        out[e.key.toString()] = v;
      } else if (v is Map) {
        out[e.key.toString()] = Map<String, dynamic>.from(v);
      }
    }
  }
  final defs = spec['definitions'];
  if (defs is Map) {
    for (final e in defs.entries) {
      final v = e.value;
      if (v is Map<String, dynamic>) {
        out[e.key.toString()] = v;
      } else if (v is Map) {
        out[e.key.toString()] = Map<String, dynamic>.from(v);
      }
    }
  }
  return out;
}

/// 在 [registry] 中解析本地 schema `$ref`；外部或未知返回 `null`。
Map<String, dynamic>? resolveLocalSchemaRef(
  Map<String, Map<String, dynamic>> registry,
  String? ref,
) {
  final name = parseLocalSchemaRef(ref);
  if (name == null) {
    return null;
  }
  return registry[name];
}

/// 遍历整棵文档树，收集非 `#/` 开头的 `$ref`（不拉取，仅告警）。
List<String> collectExternalRefWarnings(Map<String, dynamic> spec) {
  final seen = <String>{};
  void walk(dynamic node) {
    if (node is Map) {
      for (final e in node.entries) {
        if (e.key == r'$ref' && e.value is String) {
          final r = e.value as String;
          if (_isExternalRef(r)) {
            seen.add(r);
          }
        } else {
          walk(e.value);
        }
      }
    } else if (node is List) {
      for (final x in node) {
        walk(x);
      }
    }
  }
  walk(spec);
  final list = seen.toList()..sort();
  return list;
}
