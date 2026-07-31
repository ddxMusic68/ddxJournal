import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> getAppDataDirectory() async {
  if (Platform.isWindows) {
    return p.dirname(Platform.resolvedExecutable);
  }
  final dir = await getApplicationDocumentsDirectory();
  return dir.path;
}
