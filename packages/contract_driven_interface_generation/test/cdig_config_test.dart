import 'package:contract_driven_interface_generation/contract_driven_interface_generation.dart';
import 'package:contract_driven_interface_generation/src/config/cdig_config_exception.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('parseRoot: output_root, dirs, open_api_files, tag_to_file_prefix, openapi.filters, client',
      () {
    final root = loadYaml(r'''
name: example_app
contract_driven_interface_generation:
  output_root: lib/server
  open_api_files:
    - specs/api.yaml
  client: my_service
  dirs:
    apis: apis
    interfaces: interfaces
    dto: models/dto
    vo: models/vo
  tag_to_file_prefix:
    主页: home
  openapi:
    filters:
      include_path_prefixes: [/v1]
      exclude_tags: [Internal]
''') as YamlMap;

    final cfg = CdigConfig.parseRoot(
      root,
      loadedYamlPath: '/fake/project/pubspec.yaml',
    );

    expect(cfg.outputRoot, 'lib/server');
    expect(cfg.dirs.apis, 'apis');
    expect(cfg.dirs.interfaces, 'interfaces');
    expect(cfg.dirs.dto, 'models/dto');
    expect(cfg.dirs.vo, 'models/vo');
    expect(cfg.dirs.errorCodes, 'error_codes');
    expect(cfg.tagToFilePrefix, {'主页': 'home'});
    expect(cfg.openApiFilesRelative, ['specs/api.yaml']);
    expect(cfg.filters.includePathPrefixes, ['/v1']);
    expect(cfg.filters.excludeTags, ['Internal']);
    expect(cfg.client, 'my_service');
    expect(cfg.unwrapSuccessData, isTrue);
    expect(cfg.loadedYamlPath, '/fake/project/pubspec.yaml');

    expect(
      cfg.resolvePath('specs/api.yaml'),
      '/fake/project/specs/api.yaml',
    );
    expect(
      cfg.resolvedOutputRootAbsolute(),
      '/fake/project/lib/server',
    );
  });

  test('parseRoot rejects unknown keys under openapi', () {
    final root = loadYaml(r'''
name: x
contract_driven_interface_generation:
  output_root: out
  open_api_files: [a.yaml]
  openapi:
    schema_path: nested.yaml
''') as YamlMap;
    expect(
      () => CdigConfig.parseRoot(root, loadedYamlPath: '/p/pubspec.yaml'),
      throwsA(isA<FormatException>()),
    );
  });

  test('parseRoot requires open_api_files', () {
    final root = loadYaml(r'''
name: x
contract_driven_interface_generation:
  output_root: lib/server
''') as YamlMap;
    expect(
      () => CdigConfig.parseRoot(root, loadedYamlPath: '/p/pubspec.yaml'),
      throwsA(isA<FormatException>()),
    );
  });

  test('parseRoot requires output_root', () {
    final root = loadYaml(r'''
name: x
contract_driven_interface_generation:
  open_api_files: [a.yaml]
''') as YamlMap;
    expect(
      () => CdigConfig.parseRoot(root, loadedYamlPath: '/p/pubspec.yaml'),
      throwsA(isA<FormatException>()),
    );
  });

  test('parseRoot throws when section missing', () {
    final root = loadYaml('name: x') as YamlMap;
    expect(
      () => CdigConfig.parseRoot(root, loadedYamlPath: '/p/pubspec.yaml'),
      throwsA(isA<CdigConfigException>()),
    );
  });

  test('parseRoot: unwrap_success_data false', () {
    final root = loadYaml(r'''
contract_driven_interface_generation:
  output_root: out
  open_api_files: [x.yaml]
  unwrap_success_data: false
''') as YamlMap;
    final cfg = CdigConfig.parseRoot(root, loadedYamlPath: '/p/c.yaml');
    expect(cfg.unwrapSuccessData, isFalse);
  });

  test('dirs omitted uses defaults', () {
    final root = loadYaml(r'''
contract_driven_interface_generation:
  output_root: out
  open_api_files: [x.yaml]
''') as YamlMap;
    final cfg = CdigConfig.parseRoot(root, loadedYamlPath: '/p/c.yaml');
    expect(cfg.dirs, CdigDirs.defaults);
  });

  test('dirs.error_codes null or empty disables generation subdir', () {
    final root = loadYaml(r'''
contract_driven_interface_generation:
  output_root: out
  open_api_files: [x.yaml]
  dirs:
    error_codes:
''') as YamlMap;
    final cfg = CdigConfig.parseRoot(root, loadedYamlPath: '/p/c.yaml');
    expect(cfg.dirs.errorCodes, '');
  });
}
