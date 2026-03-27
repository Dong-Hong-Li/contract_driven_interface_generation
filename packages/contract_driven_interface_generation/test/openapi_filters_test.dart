import 'package:contract_driven_interface_generation/contract_driven_interface_generation.dart';
import 'package:test/test.dart';

void main() {
  test('include_path_prefixes keeps only matching paths', () {
    final spec = OpenApiDocumentLoader.parseString(
      '''
openapi: 3.0.0
paths:
  /admin/a:
    get: { tags: [Admin] }
  /public/b:
    get: {}
''',
      isJson: false,
    );
    const f = OpenApiFiltersConfig(includePathPrefixes: ['/admin']);
    final sample = OpenApiCaseSample.fromSpec(spec, filters: f);
    expect(sample.pathCount, 1);
    expect(sample.pathSamples, ['/admin/a']);
  });

  test('exclude_path_prefixes removes paths', () {
    final spec = OpenApiDocumentLoader.parseString(
      '''
openapi: 3.0.0
paths:
  /admin/a:
    get: {}
  /other/b:
    get: {}
''',
      isJson: false,
    );
    const f = OpenApiFiltersConfig(excludePathPrefixes: ['/admin']);
    final sample = OpenApiCaseSample.fromSpec(spec, filters: f);
    expect(sample.pathCount, 1);
    expect(sample.pathSamples.first, '/other/b');
  });

  test('include_tags requires tag on an operation', () {
    final spec = OpenApiDocumentLoader.parseString(
      '''
openapi: 3.0.0
paths:
  /x:
    get: { tags: [Pet] }
    post: { tags: [Store] }
''',
      isJson: false,
    );
    const f = OpenApiFiltersConfig(includeTags: ['Pet']);
    final sample = OpenApiCaseSample.fromSpec(spec, filters: f);
    expect(sample.pathCount, 1);
    expect(sample.pathSamples, ['/x']);
  });

  test('exclude_tags drops operations; path gone if no op left', () {
    final spec = OpenApiDocumentLoader.parseString(
      '''
openapi: 3.0.0
paths:
  /only:
    get: { tags: [Hidden] }
''',
      isJson: false,
    );
    const f = OpenApiFiltersConfig(excludeTags: ['Hidden']);
    final sample = OpenApiCaseSample.fromSpec(spec, filters: f);
    expect(sample.pathCount, 0);
  });
}
