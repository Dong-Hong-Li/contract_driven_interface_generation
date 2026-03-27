/// 与 [CdigConfig] 相关的配置错误。
final class CdigConfigException implements Exception {
  CdigConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}