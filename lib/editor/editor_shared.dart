import 'package:creature_bio_sim/creature.dart';

/// Marker for lateral fin drag from panel to viewport. [wingType] = which shape to add.
class LateralDragPayload {
  const LateralDragPayload({this.wingType = LateralWingType.ellipse});
  final LateralWingType wingType;
}

/// Marker for dorsal fin drag from panel to viewport.
class DorsalDragPayload {}

/// Marker for eye drag from panel to viewport (add eye at drop position).
class EyeDragPayload {}

/// Payload for tail (caudal) fin drag from panel to viewport. [tailFin] = type to add, or null to remove.
class TailDragPayload {
  const TailDragPayload(this.tailFin);
  final CaudalFinType? tailFin;
}

/// Payload for mouth drag from panel to viewport. [mouthType] = type to add/replace; [mouthCount] = 2,4,6 for teeth or 3,5,7 for tentacles (ignored for mandible).
class MouthDragPayload {
  const MouthDragPayload(this.mouthType, [this.mouthCount]);
  final MouthType mouthType;
  final int? mouthCount;
}
