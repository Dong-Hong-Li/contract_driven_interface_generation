import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// `pubspec.yaml` / 独立 YAML 里承载本工具配置的键名
const String cdigPubspecKey = 'contract_driven_interface_generation';

/// 独立配置文件默认文件名
const String cdigDefaultYamlFileName =
    'contract_driven_interface_generation.yaml';

/// 从 **当前工作目录** 查找配置文件：
///
/// 1. [explicitPath] 若给出且文件存在，则使用该路径（相对 [Directory.current] 或绝对路径）
/// 2. 否则自当前目录 **向上** 逐级父目录查找：
///    - 若存在 `contract_driven_interface_generation.yaml` 则用之
///    - 否则若存在 `pubspec.yaml` 且含 `$cdigPubspecKey` 段则用之
///
/// 这样可在子目录（如 `lib/`）执行 CLI，仍能命中项目根 `pubspec.yaml`。
File? findCdigConfigFile({String? explicitPath}) {
  if (explicitPath != null && explicitPath.trim().isNotEmpty) {
    final trimmed = explicitPath.trim();
    final candidate = p.isAbsolute(trimmed)
        ? File(p.normalize(trimmed))
        : File(p.join(Directory.current.path, trimmed));
    if (candidate.existsSync()) {
      return candidate;
    }
    return null;
  }

  var dir = Directory(p.normalize(Directory.current.path));
  while (true) {
    final dirPath = dir.path;

    final dedicated = File(p.join(dirPath, cdigDefaultYamlFileName));
    if (dedicated.existsSync()) {
      return dedicated;
    }

    final pubspec = File(p.join(dirPath, 'pubspec.yaml'));
    if (pubspec.existsSync() && _pubspecContainsCdig(pubspec)) {
      return pubspec;
    }

    final parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }
  return null;
}

bool _pubspecContainsCdig(File pubspec) {
  try {
    final root = loadYaml(pubspec.readAsStringSync());
    if (root is YamlMap && root[cdigPubspecKey] != null) {
      return true;
    }
  } catch (_) {
    // 跳过无法解析的 pubspec
  }
  return false;
}
