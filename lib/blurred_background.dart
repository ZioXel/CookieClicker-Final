import 'package:flutter/material.dart';
import 'dart:ui';

class BlurredBackground extends StatelessWidget {
  final Widget child;
  final double blurIntensity;

  const BlurredBackground({required this.child, this.blurIntensity = 10.0, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/background.jpg', // Replace with your image path
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurIntensity, sigmaY: blurIntensity),
            child: Container(
              color: Colors.black.withOpacity(0.1),
            ),
          ),
        ),
        child,
      ],
    );
  }
}