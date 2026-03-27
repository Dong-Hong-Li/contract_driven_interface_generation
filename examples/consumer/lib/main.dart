import 'package:contract_driven_interface_generation/contract_driven_interface_generation.dart';

void main() {
  // 通过函数类型引用静态方法，验证聚合包依赖解析无误。
  _holdLoader(OpenApiDocumentLoader.loadFile);
}

void _holdLoader(Future<Map<String, dynamic>> Function(String) load) {}
