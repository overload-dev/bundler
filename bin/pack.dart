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
    print("Password length must be 16 characters long.");
    exit(1);
  }

  final assetDir = Directory(assetPath);
  final outputFile = File(outputFilePath);

  if (!assetDir.existsSync()) {
    print('Asset directory does not exist');
    return;
  }

  // 1. 기존 출력 파일이 있다면 미리 삭제하여 핸들 충돌 방지
  if (outputFile.existsSync()) {
    print('Deleting existing output file...');
    outputFile.deleteSync();
  }

  print("Compressing assets...\nIt may take a while...");

  // 출력 파일의 절대 경로를 미리 계산하여 순환 참조(제외 대상) 지정
  final String absoluteOutputPath = p.canonicalize(outputFile.absolute.path);

  final archive = ZipFileEncoder();
  archive.create(outputFilePath);

  // 2. 디렉토리를 직접 순회하며 파일 추가 (출력 파일 제외 및 비동기 대기)
  final List<FileSystemEntity> entities = assetDir.listSync(recursive: true);
  for (final entity in entities) {
    if (entity is File) {
      final String absoluteEntityPath = p.canonicalize(entity.absolute.path);

      // 출력 파일이 입력 폴더 내부에 있는 경우 압축 대상에서 제외 (errno 5 방지)
      if (absoluteEntityPath == absoluteOutputPath) {
        continue;
      }

      // 상대 경로를 유지하며 압축 파일에 추가
      final String relativePath = p.relative(entity.path, from: assetDir.path);
      
      // archive 4.x 대응: 비동기 추가 작업 대기
      await archive.addFile(entity, relativePath);
    }
  }

  // 3. 압축 스트림을 확실히 닫을 때까지 대기
  await archive.close();

  // 4. AES 암호화 단계
  print("Encrypting bundle...");
  
  // 압축이 완전히 끝난 후 파일을 읽어 암호화 진행
  final outputFileBytes = await outputFile.readAsBytes();
  final encryptedBytes = await Bundler().aesEncrypt(outputFileBytes, password);
  
  // 암호화된 데이터로 원본 파일 덮어쓰기
  await outputFile.writeAsBytes(encryptedBytes);

  print("Assets compressed and encrypted successfully: $outputFilePath");
}
