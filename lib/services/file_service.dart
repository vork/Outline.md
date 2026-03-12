import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/outline_document.dart';
import 'markdown_parser.dart';
import 'markdown_serializer.dart';

class FileService {
  final _parser = MarkdownParser();
  final _serializer = MarkdownSerializer();

  Future<OutlineDocument?> openFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown', 'txt'],
      dialogTitle: 'Open Outline',
    );

    if (result == null || result.files.isEmpty) return null;

    final path = result.files.single.path;
    if (path == null) return null;

    final file = File(path);
    final content = await file.readAsString();
    return _parser.parse(content, filePath: path);
  }

  Future<String?> saveFile(OutlineDocument doc) async {
    if (doc.filePath != null) {
      final file = File(doc.filePath!);
      final content = _serializer.serialize(doc);
      await file.writeAsString(content);
      return doc.filePath;
    }
    return saveFileAs(doc);
  }

  Future<String?> saveFileAs(OutlineDocument doc) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Outline',
      fileName: '${doc.title.replaceAll(RegExp(r'[^\w\s-]'), '')}.md',
      type: FileType.custom,
      allowedExtensions: ['md'],
    );

    if (path == null) return null;

    final finalPath = path.endsWith('.md') ? path : '$path.md';
    final file = File(finalPath);
    final content = _serializer.serialize(doc);
    await file.writeAsString(content);
    return finalPath;
  }

  Future<OutlineDocument> loadFromPath(String path) async {
    final file = File(path);
    final content = await file.readAsString();
    return _parser.parse(content, filePath: path);
  }

  Future<String> getDefaultDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }
}
