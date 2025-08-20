import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImageService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Pick multiple images
  static Future<List<String>?> pickMultipleImages() async {
    try {
      final ImagePicker picker = ImagePicker();

      // Pick multiple images at once using pickMultiImage
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        List<String> base64Images = [];

        for (XFile image in images) {
          File imageFile = File(image.path);
          List<int> imageBytes = await imageFile.readAsBytes();
          String base64Image = base64Encode(imageBytes);
          base64Images.add(base64Image);
        }

        return base64Images;
      }
      return null;
    } catch (e) {
      debugPrint('Error selecting images: $e');
      throw e;
    }
  }

  // Confirm day with images
  static Future<void> confirmDay(
    String userId,
    String dateString,
    Map<String, dynamic> dayData,
    List<String>? selectedImages,
  ) async {
    final hasExistingImages = (dayData['attachmentImages'] as List).isNotEmpty;
    final hasSelectedImages = (selectedImages ?? []).isNotEmpty;

    // Check if day is not confirmed and has no images
    if (!dayData['confirmed'] && !hasExistingImages && !hasSelectedImages) {
      throw Exception('You have to upload image first');
    }

    try {
      Map<String, dynamic> updateData = {'confirmed': true};

      // If there are selected images, upload them
      if ((selectedImages ?? []).isNotEmpty) {
        // Get existing attachment images
        List<String> existingImages = List<String>.from(
          dayData['attachmentImages'] ?? [],
        );
        // Add selected images to existing ones
        existingImages.addAll(selectedImages!);
        // Update with the complete list instead of using arrayUnion to avoid duplication
        updateData['attachmentImages'] = existingImages;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('calendarDays')
          .doc(dateString)
          .update(updateData);
    } catch (e) {
      debugPrint('Error confirming day: $e');
      throw e;
    }
  }
}
