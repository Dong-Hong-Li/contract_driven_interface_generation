import 'package:yaml/yaml.dart';

/// 将 [YamlMap] / [YamlList] 转为 Dart 结构（最小迁移自 `copy/lib/src/parser/corrector/open_api_corrector.dart` 中 `YamlMapX.toMap`）。
///
/// 相对原实现：标量保留 `int`/`double`/`bool`/`String`，不强制 `.toString()`。
extension YamlMapX on YamlMap {
  Map<String, dynamic> toJsonStyleMap() {
    final out = <String, dynamic>{};
    for (final e in entries) {
      out[e.key.toString()] = yamlNodeToDart(e.value);
    }
    return out;
  }
}

/// 递归把 `package:yaml` 节点转成与 [jsonDecode] 相近的 Dart 结构。
dynamic yamlNodeToDart(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is YamlMap) {
    return value.toJsonStyleMap();
  }
  if (value is YamlList) {
    return value.map(yamlNodeToDart).toList(growable: false);
  }
  return value;
}
