import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;

class Base64ImageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  // Convert image to Base64 with compression
  Future<String?> imageToBase64({
    required File imageFile,
    int maxWidth = 800,
    int maxHeight = 600,
    int quality = 85,
  }) async {
    try {
      // Read image bytes
      Uint8List imageBytes = await imageFile.readAsBytes();

      // Decode and resize image
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) return null;

      // Resize image
      img.Image resizedImage = img.copyResize(
        originalImage,
        width: maxWidth,
        height: maxHeight,
      );

      // Compress image
      Uint8List compressedBytes = Uint8List.fromList(
        img.encodeJpg(resizedImage, quality: quality),
      );

      // Convert to Base64
      String base64String = base64Encode(compressedBytes);

      print('Original size: ${imageBytes.length} bytes');
      print('Compressed size: ${compressedBytes.length} bytes');

      return base64String;
    } catch (e) {
      print('Error converting image to Base64: $e');
      return null;
    }
  }

  // Convert Base64 back to image widget
  Widget base64ToImage(String base64String, {double? width, double? height}) {
    try {
      Uint8List imageBytes = base64Decode(base64String);
      return Image.memory(
        imageBytes,
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    } catch (e) {
      return const Icon(Icons.error, color: Colors.red);
    }
  }

  // Pick and convert image
  Future<String?> pickAndConvertImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        File imageFile = File(image.path);
        return await imageToBase64(imageFile: imageFile);
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  // Save image to Firestore
  Future<bool> saveImageToFirestore({
    required String documentPath,
    required String base64Image,
    String fieldName = 'image',
  }) async {
    try {
      await _firestore.doc(documentPath).update({
        fieldName: base64Image,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error saving image to Firestore: $e');
      return false;
    }
  }

  // Add image to array in Firestore
  Future<bool> addImageToArray({
    required String documentPath,
    required String base64Image,
    String fieldName = 'images',
  }) async {
    try {
      await _firestore.doc(documentPath).update({
        fieldName: FieldValue.arrayUnion([base64Image]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error adding image to array: $e');
      return false;
    }
  }
}