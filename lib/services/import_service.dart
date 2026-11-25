import 'import_service_stub.dart'
    if (dart.library.html) 'import_service_web.dart';

/// Открывает диалог выбора JSON-файла. Вне браузера возвращает null.
Future<String?> pickJsonFile() => pickJsonFileImpl();
