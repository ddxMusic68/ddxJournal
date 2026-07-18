import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class MediaService {
  final ImagePicker _picker = ImagePicker();

  Future<String> get _mediaDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(appDir.path, 'media'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir.path;
  }

  Future<String?> pickImage({ImageSource source = ImageSource.gallery}) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return null;

    final dir = await _mediaDir;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}${p.extension(image.path)}';
    final savedPath = p.join(dir, fileName);
    await File(image.path).copy(savedPath);
    return savedPath;
  }

  Future<String> compressImage(String path) async {
    final dir = await _mediaDir;
    final fileName = p.basenameWithoutExtension(path);
    final ext = p.extension(path);
    final outPath = p.join(dir, '${fileName}_compressed$ext');

    final result = await FlutterImageCompress.compressAndGetFile(
      path,
      outPath,
      quality: 70,
      minWidth: 1024,
      minHeight: 1024,
    );

    return result?.path ?? path;
  }

  Future<void> deleteMedia(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
