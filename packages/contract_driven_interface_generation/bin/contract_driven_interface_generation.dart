import 'dart:io';

import 'package:contract_driven_interface_generation/contract_driven_interface_generation.dart';
import 'package:contract_driven_interface_generation_net_retrofit/contract_driven_interface_generation_net_retrofit.dart';
import 'package:path/path.dart' as p;

/// 1. 读取 `contract_driven_interface_generation`（output_root、dirs、open_api_files 等）
/// 2. 合并多文件后解析 OpenAPI
/// 3. 在 [output_root] 下写入 `openapi_case_sample.txt`、`openapi_parsed.json`
/// 4. 调用独立模块生成 `net_retrofit_dio` 风格 apis / interfaces / models
Future<void> main(List<String> arguments) async {
  String? configFile;
  for (var i = 0; i < arguments.length; i++) {
    final a = arguments[i];
    if (a == '-h' || a == '--help') {
      stdout.writeln('''
用法: dart run contract_driven_interface_generation [选项]

选项:
  -f, --config <路径>   指定 pubspec.yaml 或 contract_driven_interface_generation.yaml
  -h, --help            显示此帮助

未指定 -f 时：从当前目录向上查找「含 contract_driven_interface_generation 段」的 pubspec.yaml，
或任意目录下的 contract_driven_interface_generation.yaml。

output_root、open_api_files 等路径均相对于**含配置的 pubspec 所在目录**（项目根）解析，
与终端 cwd 无关；在子目录执行时会向上找到该 pubspec，仍以该目录为基准。
''');
      return;
    }
    if (a == '-f' || a == '--config') {
      if (i + 1 >= arguments.length) {
        stderr.writeln('错误: $a 需要后跟配置文件路径');
        exitCode = 64;
        return;
      }
      configFile = arguments[++i];
    }
  }

  final cfg = await CdigConfig.load(configFile: configFile);
  final paths = cfg.resolvedOpenApiAbsolutePaths();

  final Map<String, dynamic> spec;
  if (paths.length == 1) {
    spec = await OpenApiDocumentLoader.loadFile(paths.first);
  } else {
    final maps = await Future.wait(paths.map(OpenApiDocumentLoader.loadFile));
    spec = mergeOpenApiDocuments(maps);
  }

  final sample = OpenApiCaseSample.fromSpec(
    spec,
    filters: cfg.filters,
  );

  final outRoot = Directory(cfg.resolvedOutputRootAbsolute());
  await outRoot.create(recursive: true);
  final outFile = File(p.join(outRoot.path, 'openapi_case_sample.txt'));
  await outFile.writeAsString(sample.toReport());

  final jsonFile = File(p.join(outRoot.path, 'openapi_parsed.json'));
  await jsonFile.writeAsString(encodeParsedOpenApiDocumentJson(sample.parsed));

  final codegen = await writeNetRetrofitCodegen(
    document: sample.parsed,
    rawSpec: spec,
    outputRootAbsolute: outRoot.path,
    dirs: cfg.dirs,
    tagToFilePrefix: cfg.tagToFilePrefix,
    netApiClient: cfg.client,
    unwrapSuccessData: cfg.unwrapSuccessData,
  );

  final tagLine = cfg.tagToFilePrefix.isEmpty
      ? 'tag_to_file_prefix: （未配置，可选）'
      : 'tag_to_file_prefix: ${cfg.tagToFilePrefix.length} 条映射';

  stdout
    ..writeln('OpenAPI: ${paths.join(', ')}')
    ..writeln('output_root: ${outRoot.path}')
    ..writeln('dirs: apis=${cfg.dirs.apis}, interfaces=${cfg.dirs.interfaces}, '
        'dto=${cfg.dirs.dto}, vo=${cfg.dirs.vo}')
    ..writeln(tagLine)
    ..writeln('已生成: ${outFile.path}')
    ..writeln('已生成: ${jsonFile.path}')
    ..writeln('NetRetrofit 代码: ${codegen.writtenPaths.length} 个文件');
}
