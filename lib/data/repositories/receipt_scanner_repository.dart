import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/helpers/receipt_parser.dart';

enum ReceiptImageSource { camera, gallery }

/// Menangani pemilihan gambar (kamera/galeri) dan pembacaan teksnya
/// menggunakan Google ML Kit Text Recognition, sepenuhnya lokal di
/// perangkat — tidak ada gambar yang dikirim ke server manapun.
class ReceiptScannerRepository {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<File?> pickImage(ReceiptImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source == ReceiptImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 90,
    );
    if (file == null) return null;
    return File(file.path);
  }

  Future<ReceiptParseResult> extractFromImage(File image) async {
    final inputImage = InputImage.fromFile(image);
    final recognizedText = await _recognizer.processImage(inputImage);
    return ReceiptParser.parse(recognizedText.text);
  }

  void close() {
    _recognizer.close();
  }
}
