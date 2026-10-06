import 'dart:math' as math;

final _nameQuery = RegExp(r'^[a-zа-я ]+$');

/// Distance to the beginning of a normalized trade name. Keep short queries and
/// numbers exact; suggestions never change the selected source name or dose.
int? drugNameTypoDistance(String name, String query) {
  if (query.length < 4 || !_nameQuery.hasMatch(query)) return null;
  final allowance = query.length >= 7 ? 2 : 1;
  if (name.length < query.length - allowance) return null;
  final candidate = name.substring(
    0,
    math.min(name.length, query.length + allowance),
  );
  var previous = List.generate(candidate.length + 1, (i) => i);
  var beforePrevious = previous;
  for (var i = 1; i <= query.length; i++) {
    final current = List.filled(candidate.length + 1, allowance + 1);
    current[0] = i;
    final from = math.max(1, i - allowance);
    final to = math.min(candidate.length, i + allowance);
    for (var j = from; j <= to; j++) {
      final substitution =
          query.codeUnitAt(i - 1) == candidate.codeUnitAt(j - 1) ? 0 : 1;
      current[j] = math.min(
        math.min(previous[j] + 1, current[j - 1] + 1),
        previous[j - 1] + substitution,
      );
      if (i > 1 &&
          j > 1 &&
          query.codeUnitAt(i - 1) == candidate.codeUnitAt(j - 2) &&
          query.codeUnitAt(i - 2) == candidate.codeUnitAt(j - 1)) {
        current[j] = math.min(current[j], beforePrevious[j - 2] + 1);
      }
    }
    if (current.reduce(math.min) > allowance) return null;
    beforePrevious = previous;
    previous = current;
  }
  final distance = previous
      .skip(math.max(0, query.length - allowance))
      .reduce(math.min);
  return distance <= allowance ? distance : null;
}
