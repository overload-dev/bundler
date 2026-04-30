import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:bundler/bundler.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length < 3) {
    print('Usage: bundler:pack <input> <output> <password>');
    exit(1);
  }

  final assetPath = arguments[0];
  final outputFilePath = arguments[1];
  final password = arguments[2];

  if (password.length != 16) {
    print("Password length must be 16");
    exit(1);
  }

  final assetDir = Directory(assetPath);
  final outputFile = File(outputFilePath);

  if (!assetDir.existsSync()) {
    print('Asset directory does not exist');
    return;
  }

  if (outputFile.existsSync()) {
    // 기존 파일이 있다면 삭제하여 충돌 방지 (혹은 에러 처리)
    print('Output file already exists. Deleting existing file...');
    outputFile.deleteSync();
  }

  print("Compressing assets...\nIt may take a while...");

  // 출력 파일의 절대 경로를 미리 계산하여 제외 대상으로 지정
  final String absoluteOutputPath = p.canonicalize(outputFile.absolute.path);

  final archive = ZipFileEncoder();
  archive.create(outputFilePath);

  // addDirectory 대신 파일을 순회하며 수동으로 추가 (자기 자신 제외 로직)
  final List<FileSystemEntity> entities = assetDir.listSync(recursive: true);
  for (final entity in entities) {
    if (entity is File) {
      final String absoluteEntityPath = p.canonicalize(entity.absolute.path);

      // 현재 쓰기 작업 중인 출력 파일이 입력 디렉토리 안에 포함되어 있다면 제외
      if (absoluteEntityPath == absoluteOutputPath) {
        continue;
      }

      // 상대 경로를 유지하며 압축 파일에 추가
      final String relativePath = p.relative(entity.path, from: assetDir.path);
      archive.addFile(entity, relativePath);
    }
  }

  archive.close();

  // AES encrypt the file
  print("Encrypting bundle...");
  final outputFileBytes = await outputFile.readAsBytes();
  final encryptedBytes = await Bundler().aesEncrypt(outputFileBytes, password);
  await outputFile.writeAsBytes(encryptedBytes);

  print("Assets compressed and encrypted successfully: $outputFilePath");
}
