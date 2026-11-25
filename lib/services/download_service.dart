import 'download_service_stub.dart'
    if (dart.library.html) 'download_service_web.dart';

/// Скачивает HTML-файл в браузере. В тестах (VM) ничего не делает.
void downloadHtmlFile(String filename, String content) =>
    downloadHtmlFileImpl(filename, content);

/// Скачивает JSON-файл в браузере.
void downloadJsonFile(String filename, String content) =>
    downloadJsonFileImpl(filename, content);
