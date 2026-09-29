String russianCount(int count, String one, String few, String many) {
  final lastTwo = count % 100;
  final last = count % 10;
  final word = lastTwo >= 11 && lastTwo <= 14
      ? many
      : last == 1
      ? one
      : last >= 2 && last <= 4
      ? few
      : many;
  return '$count $word';
}
