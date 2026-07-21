import 'dart:io';
import 'package:flutter/material.dart';

class PhotoAvatar extends StatelessWidget {
  final String? photoPath;
  final String initials;
  final Color backgroundColor;
  final double size;
  final double borderRadius;

  const PhotoAvatar({
    super.key,
    this.photoPath,
    required this.initials,
    required this.backgroundColor,
    this.size = 56,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasValidImage = photoPath != null &&
        photoPath!.isNotEmpty &&
        File(photoPath!).existsSync();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: hasValidImage ? null : backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        image: hasValidImage
            ? DecorationImage(
                image: FileImage(File(photoPath!)),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasValidImage
          ? null
          : Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w700,
                  color: backgroundColor == Colors.amber.shade100
                      ? Colors.brown
                      : backgroundColor.computeLuminance() > 0.5
                          ? Colors.black87
                          : Colors.white,
                ),
              ),
            ),
    );
  }
}
