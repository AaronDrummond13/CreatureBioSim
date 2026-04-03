import 'package:flutter/material.dart';

/// World biome. Used for background and dot/bubble/blob tint; later for creatures, objects, etc.
enum Biome { clear, deep, algae, poisoned, dirty, wasteland }

extension BiomeColors on Biome {
  /// Base colour for this biome (background tint, dot tint).
  Color get color {
    switch (this) {
      case Biome.clear:
        return const Color.fromARGB(255, 40, 76, 95); // gentle blue
      case Biome.deep:
        return const Color.fromARGB(255, 16, 56, 102); // darker blue
      case Biome.algae:
        return const Color.fromARGB(255, 34, 83, 49); // greenish
      case Biome.poisoned:
        return const Color.fromARGB(255, 88, 73, 121); // purplish
      case Biome.dirty:
        return const Color.fromARGB(255, 87, 80, 59); // brownish
      case Biome.wasteland:
        return const Color.fromARGB(255, 68, 94, 108); // same as clear
    }
  }
}
