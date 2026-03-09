import 'package:flutter/material.dart';

/// World biome. Used for background and dot/bubble/blob tint; later for creatures, objects, etc.
enum Biome { clear, deep, algae, poisoned, dirty, wasteland }

extension BiomeColors on Biome {
  /// Base colour for this biome (background tint, dot tint).
  Color get color {
    switch (this) {
      case Biome.clear:
        return const Color.fromARGB(255, 72, 134, 168); // gentle blue
      case Biome.deep:
        return const Color.fromARGB(255, 27, 96, 174); // darker blue
      case Biome.algae:
        return const Color.fromARGB(255, 66, 158, 93); // greenish
      case Biome.poisoned:
        return const Color.fromARGB(255, 139, 116, 190); // purplish
      case Biome.dirty:
        return const Color.fromARGB(255, 162, 149, 108); // brownish
      case Biome.wasteland:
        return const Color.fromARGB(255, 121, 166, 190); // same as clear
    }
  }
}
