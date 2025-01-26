import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ImageUploadService {
  final CloudinaryPublic _cloudinary = CloudinaryPublic(
      dotenv.env['CLOUDINARY_CLOUD_NAME']!,
      dotenv.env['CLOUDINARY_UPLOAD_PRESET']!,
      cache: false,
  );

  Future<String?> uploadImageFile(BuildContext context, File imageFile) async {

    // Validation max file size to be 5MB
    final fileSize = await imageFile.length();
    if(fileSize > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image size should be less than 5MB')),
      );
      return null;
    }

    // Validation file format, should be .jpeg, .png, .jpg
    final fileExtension = imageFile.path.split('.').last.toLowerCase();
    if(fileExtension != 'jpeg' && fileExtension != 'png' && fileExtension != 'jpg') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image format should be .jpeg, .png, .jpg')),
      );
      return null;
    }

    try {
      final response = await _cloudinary.uploadFile(
          CloudinaryFile.fromFile(
              imageFile.path,
              folder: 'chat_images'
          )
      );
      return response.secureUrl;
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  Future<File?> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    return pickedFile != null ? File(pickedFile.path) : null;
  }
}