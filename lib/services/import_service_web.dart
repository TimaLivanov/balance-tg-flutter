import 'dart:async';
import 'dart:html' as html;

Future<String?> pickJsonFileImpl() {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()
    ..accept = '.json,application/json'
    ..style.display = 'none';
  html.document.body!.children.add(input);
  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      input.remove();
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      input.remove();
      if (!completer.isCompleted) completer.complete(reader.result as String?);
    });
    reader.onError.listen((_) {
      input.remove();
      if (!completer.isCompleted) completer.complete(null);
    });
    reader.readAsText(files.first);
  });
  input.click();
  return completer.future;
}
