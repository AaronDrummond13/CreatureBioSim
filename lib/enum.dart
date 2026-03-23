import 'dart:math';

extension EnumX<T extends Enum> on List<T> {
  T random([Random? rng]) {
    rng ??= Random();
    return this[rng.nextInt(length)];
  }
}
