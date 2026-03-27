import 'package:contract_driven_interface_generation/contract_driven_interface_generation.dart';
import 'package:test/test.dart';

void main() {
  test('parseString YAML matches openapi 3 root', () {
    const yaml = '''
openapi: 3.0.0
info:
  title: T
  version: 1
paths:
  /a:
    get: {}
''';
    final map = OpenApiDocumentLoader.parseString(yaml, isJson: false);
    expect(map['openapi'], '3.0.0');
    expect((map['info'] as Map)['title'], 'T');
    expect((map['paths'] as Map).length, 1);
  });

  test('OpenApiCaseSample summarizes paths', () {
    final map = OpenApiDocumentLoader.parseString(
      '''
openapi: 3.0.1
info:
  title: X
  version: 2
paths:
  /z: {}
  /y: {}
''',
      isJson: false,
    );
    final s = OpenApiCaseSample.fromSpec(map);
    expect(s.pathCount, 2);
    expect(s.toReport(), contains('paths 数量: 2'));
  });
}
