# contract_driven_interface_generation

由 **OpenAPI 契约** 驱动生成 **NetRetrofit / Dio** 风格 Dart 代码（接口、模型、路径常量、HTTP/业务错误码常量等）的 **Melos 单仓库**。

## 仓库结构

| 路径 | 说明 |
|------|------|
| `packages/contract_driven_interface_generation` | 核心：配置解析、OpenAPI 加载与解析、CLI `dart run contract_driven_interface_generation` |
| `packages/contract_driven_interface_generation_net_retrofit` | 生成 NetRetrofit 风格 `apis` / `interfaces` / `models` / `error_codes` |
| `examples/consumer` | Flutter 示例：path 依赖 + 完整生成链路（含 `build_runner` 出 `.g.dart`） |
| `tool/*.sh` | 根目录一键脚本（由 Melos 调用） |

## 环境要求

- Dart SDK **`>=3.5.0 <4.0.0`**（与各子包 `environment.sdk` 一致）
- Flutter **>=3.16.0**（仅 `examples/consumer` 需要，见该包 `environment.flutter`）
- **Flutter**（跑 `examples/consumer` 与 `net_retrofit_dio` 生成物）
- 仓库根执行：`dart pub get` 已安装 **Melos**（见根目录 `pubspec.yaml`）

## 快速开始

在**仓库根目录**：

```bash
dart pub get
dart run melos bootstrap
dart run melos run codegen:example
dart run melos run run:example
```

| 命令 | 作用 |
|------|------|
| `dart run melos bootstrap` | 为所有包执行 `pub get`（consumer 使用 `flutter pub get`） |
| `dart run melos run codegen:example` | 在 `examples/consumer`：OpenAPI → `lib/generated` + `build_runner` |
| `dart run melos run run:example` | 运行 `examples/consumer` 的 `lib/main.dart` |
| `dart run melos run analyze` | 各包静态分析 |
| `dart run melos run test` | 有 `test/` 的包跑单元测试 |

脚本依赖 **bash**（macOS / Linux / Git Bash）。也可手动在 `examples/consumer` 下执行：

```bash
cd examples/consumer
flutter pub get
dart run contract_driven_interface_generation
dart run build_runner build --delete-conflicting-outputs
dart run lib/main.dart
```

## 在你自己的 Flutter 工程里使用

### 1. 依赖

在业务工程 `pubspec.yaml` 中增加 path 或 git（二选一），例如 path：

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.9.0
  net_retrofit_dio: ^0.2.0
  contract_driven_interface_generation:
    path: ../contract_driven_interface_generation/packages/contract_driven_interface_generation

dev_dependencies:
  build_runner: ^2.13.0
```

> **包名与目录名必须一致**：核心包目录名为 `contract_driven_interface_generation`，`name` 字段同名。

### 2. 生成配置（写在业务工程 `pubspec.yaml` 根级）

```yaml
contract_driven_interface_generation:
  output_root: lib/generated
  open_api_files:
    - openapi/api.yaml
  unwrap_success_data: false   # 可选，默认 true
  dirs:
    apis: apis
    interfaces: interfaces
    dto: models/dto
    vo: models/vo
    # error_codes: error_codes   # 默认；写成 '' 或 null 则不生成 openapi_error_codes.dart
  tag_to_file_prefix: {}         # 可选：中文 tag → 文件名前缀
```

- **`output_root` / `open_api_files`**：路径均相对于**本 `pubspec.yaml` 所在目录**（项目根），与终端当前目录无关；在子目录执行 CLI 时会向上查找含该段的 `pubspec`。
- **CLI**：`dart run contract_driven_interface_generation`；可用 `-f` / `--config` 指定配置文件。

### 3. 生成步骤

```bash
dart run contract_driven_interface_generation
dart run build_runner build --delete-conflicting-outputs
```

生成代码会 `import 'package:net_retrofit_dio/net_retrofit_dio.dart'` 并 `part '*.g.dart'`，因此需要上述依赖与 `build_runner`。

## 解析层说明

OpenAPI 解析与设计要点见：

`packages/contract_driven_interface_generation/docs/PARSE_LAYER.md`

## 许可与发布

各包当前多为 `publish_to: none`，仅供仓库内与 path/git 引用；若需发布 pub.dev，需单独调整版本与发布策略。
