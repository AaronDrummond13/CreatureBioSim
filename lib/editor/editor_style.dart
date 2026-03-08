import 'package:flutter/material.dart';

/// Same dark base as play mode (simulation_screen bgColor base).
const Color kEditorBackground = Color.fromARGB(255, 28, 30, 54);

const double kFinRemoveMargin = 100.0;
const double kDorsalGrabRadius = 20.0;
const double kLateralGrabRadius = 22.0;

/// Shared editor UI: curves and fills to match game aesthetic (no Material).
class EditorStyle {
  EditorStyle._();

  static const Color stroke = Color(0xFF6b8a9e);
  static const Color fill = Color(0xFF2e3d4d);
  static const Color selected = Color(0xFF3d5a6e);
  static const Color text = Color(0xFFe8eef2);
  static const Color textMuted = Color(0xFF8fa3b0);
  static const double radius = 8.0;
  static const double strokeWidth = 1.5;
}

/// Dorsal height presets (world units). null = renderer default.
const double? kDorsalHeightDefault = null;
const double kDorsalHeightSmall = 8.0;
const double kDorsalHeightMedium = 14.0;
const double kDorsalHeightLarge = 22.0;
