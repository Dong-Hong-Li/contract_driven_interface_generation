/// 命名与路径常量（对齐 Go `cdig` `name_utils` / `path_const_name`）。
library;

String refToDartName(String ref) {
  final s = ref.trim();
  final i = s.lastIndexOf('.');
  if (i >= 0 && i < s.length - 1) {
    return s.substring(i + 1);
  }
  return s;
}

String toSnake(String s) {
  final n = normalizeName(s);
  return n.replaceAll('-', '_');
}

String resolveFilePrefix(String group, Map<String, String> tagToFilePrefix) {
  final g = group.trim();
  final mapped = tagToFilePrefix[g];
  if (mapped != null) {
    final p = toSnake(mapped);
    if (p.isNotEmpty) {
      return p;
    }
  }
  return toSnake(group);
}

String normalizeName(String s) {
  var t = s.trim();
  if (t.isEmpty) {
    return 'common';
  }
  var parts = splitParts(t);
  if (parts.isEmpty) {
    parts = ['common'];
  }
  return parts.join('_');
}

String toPascal(String s) {
  final n = normalizeName(s);
  final parts = n.replaceAll('_', ' ').split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
  final buf = StringBuffer();
  for (final p in parts) {
    if (p.isEmpty) {
      continue;
    }
    buf.write(p[0].toUpperCase());
    if (p.length > 1) {
      buf.write(p.substring(1));
    }
  }
  final out = buf.toString();
  return out.isEmpty ? 'Common' : out;
}

List<String> splitParts(String s) {
  var t = s.trim().replaceAll('-', ' ').replaceAll('_', ' ');
  final buf = StringBuffer();
  for (final r in t.runes) {
    final c = String.fromCharCode(r);
    if (c.length == 1) {
      final ch = c.codeUnitAt(0);
      if (ch >= 65 && ch <= 90) {
        buf.write(' ');
        buf.write(String.fromCharCode(ch + 32));
      } else if ((ch >= 97 && ch <= 122) ||
          (ch >= 48 && ch <= 57) ||
          ch == 32) {
        buf.write(c);
      } else {
        buf.write(' ');
      }
    }
  }
  return buf.toString().trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
}

String pathToConstName(String path) {
  var trimmed = path.trim();
  if (trimmed.startsWith('/')) {
    trimmed = trimmed.substring(1);
  }
  if (trimmed.endsWith('/')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  if (trimmed.isEmpty) {
    return 'root';
  }
  final segments = trimmed.split('/');
  final words = <String>[];
  for (var segment in segments) {
    segment = segment.trim().replaceAll('{', ' ').replaceAll('}', ' ');
    if (segment.isEmpty) {
      continue;
    }
    var parts = splitParts(segment);
    if (parts.isEmpty) {
      parts = [segment];
    }
    words.addAll(parts);
  }
  if (words.isEmpty) {
    return 'path';
  }
  var name = words.first;
  for (var i = 1; i < words.length; i++) {
    final w = words[i];
    if (w.isEmpty) {
      continue;
    }
    name += w[0].toUpperCase() + w.substring(1);
  }
  if (name.isEmpty) {
    return 'path';
  }
  final first = name.codeUnitAt(0);
  final ok = (first >= 97 && first <= 122) ||
      (first >= 65 && first <= 90) ||
      first == 95;
  if (!ok) {
    name = 'path${name[0].toUpperCase()}${name.substring(1)}';
  }
  return name;
}

String toCamelIdentifier(String s) {
  final pascal = toPascal(s);
  if (pascal.isEmpty) {
    return 'request';
  }
  final first = pascal[0].toLowerCase();
  final rest = pascal.length > 1 ? pascal.substring(1) : '';
  var out = '$first$rest';
  final c0 = out.codeUnitAt(0);
  if (c0 >= 48 && c0 <= 57) {
    out = 'request${pascal[0].toUpperCase()}${pascal.substring(1)}';
  }
  return out;
}

String httpAnnotation(String method) {
  switch (method.toLowerCase().trim()) {
    case 'post':
    case 'patch':
      return 'Post';
    case 'put':
      return 'Put';
    case 'delete':
      return 'Delete';
    default:
      return 'Get';
  }
}

String jsonKeyToDartName(String key) {
  final parts = splitParts(key.replaceAll(r'$', ' '));
  if (parts.isEmpty) {
    return 'value';
  }
  var out = parts.first;
  for (var i = 1; i < parts.length; i++) {
    final p = parts[i];
    if (p.isEmpty) {
      continue;
    }
    out += p[0].toUpperCase() + p.substring(1);
  }
  const reserved = {'in', 'is', 'do', 'void', 'class', 'enum', 'return'};
  if (reserved.contains(out)) {
    out = '${out}Value';
  }
  return out;
}
