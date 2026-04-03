/// Shared rules for dorsal fins. Used by spawner and editor so constraints live in one place.
///
/// Rules:
/// - Each fin spans at least [minSegmentsPerFin] segments (default 2).
/// - No segment may belong to more than one fin (no overlapping or duplicate segments).
/// - Spawner uses [maxFinsForSpawner] to cap the number of random fins.
library;

/// Minimum number of segments per dorsal fin.
const int dorsalFinMinSegments = 2;

/// Maximum number of dorsal fins when randomly spawning a creature.
const int dorsalFinMaxFinsForSpawner = 3;

/// True if [segs] is a valid dorsal fin range: length >= [dorsalFinMinSegments]
/// and every segment in [0, segmentCount).
bool dorsalFinRangeValid(List<int> segs, int segmentCount) {
  if (segs.length < dorsalFinMinSegments) return false;
  for (final s in segs) {
    if (s < 0 || s >= segmentCount) return false;
  }
  return true;
}

/// Set of segment indices used by fins other than the one at [excludeIndex].
Set<int> dorsalFinSegmentsUsedByOthers(
  List<(List<int>, double?)> fins,
  int excludeIndex,
) {
  final used = <int>{};
  for (var i = 0; i < fins.length; i++) {
    if (i == excludeIndex) continue;
    for (final s in fins[i].$1) used.add(s);
  }
  return used;
}

/// True if no segment appears in more than one fin.
bool dorsalFinsNonOverlapping(List<(List<int>, double?)> fins) {
  final used = <int>{};
  for (final f in fins) {
    for (final s in f.$1) {
      if (used.contains(s)) return false;
      used.add(s);
    }
  }
  return true;
}

/// True if [fins] is valid: each fin has a valid range for [segmentCount] and no overlapping segments.
bool dorsalFinListValid(List<(List<int>, double?)>? fins, int segmentCount) {
  if (fins == null || fins.isEmpty) return true;
  for (final f in fins) {
    if (!dorsalFinRangeValid(f.$1, segmentCount)) return false;
  }
  return dorsalFinsNonOverlapping(fins);
}

/// True if setting fin [finIndex] to segments [start..end] (inclusive) keeps the list valid.
bool dorsalFinCanSetRange(
  List<(List<int>, double?)> fins,
  int finIndex,
  int start,
  int end,
  int segmentCount,
) {
  if (finIndex < 0 || finIndex >= fins.length) return false;
  final segs = [for (var i = start; i <= end; i++) i];
  if (!dorsalFinRangeValid(segs, segmentCount)) return false;
  final used = dorsalFinSegmentsUsedByOthers(fins, finIndex);
  for (final s in segs) {
    if (used.contains(s)) return false;
  }
  return true;
}

/// True if adding a new fin with segments [start..end] (inclusive) keeps [fins] valid.
bool dorsalFinCanAdd(
  List<(List<int>, double?)> fins,
  int start,
  int end,
  int segmentCount,
) {
  final segs = [for (var i = start; i <= end; i++) i];
  if (!dorsalFinRangeValid(segs, segmentCount)) return false;
  final used = dorsalFinSegmentsUsedByOthers(fins, -1);
  for (final s in segs) {
    if (used.contains(s)) return false;
  }
  return true;
}
