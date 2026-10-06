final _words = RegExp(r'[A-Za-zА-Яа-яЁё]+');
final _romanNumber = RegExp(r'^[IVXLCDM]+$');
const _abbreviations = {
  'ООО',
  'АО',
  'ОАО',
  'ПАО',
  'ЗАО',
  'НАО',
  'OOO',
  'LLC',
  'LTD',
  'INC',
  'ЛТД',
  'ИНК',
  'ГМБХ',
  'ЛЛС',
  'АГ',
  'АБ',
  'МНН',
  'РУ',
  'МЕ',
  'ЕД',
  'КОЕ',
  'КИЕ',
  'АТрЕ',
  'GTIN',
  'АКДС',
  'АДС',
  'БЦЖ',
  'АЦЦ',
  'КАПД',
  'ДПКА',
  'ДНК',
  'РНК',
  'ВИЧ',
  'ВПЧ',
  'АКОС',
  'УБФ',
  'МВ',
  'SR',
  'XR',
  'XL',
  'OBL',
  'COVID',
  'SARS',
  'HIV',
};

/// Quiet all-capital source words while retaining existing mixed-case spelling,
/// known abbreviations, Roman numerals, numbers, punctuation and units.
String readableDrugText(String value, {bool name = false}) {
  var firstWord = true;
  return value.replaceAllMapped(_words, (match) {
    final word = match.group(0)!;
    final first = firstWord;
    firstWord = false;
    if (word == word.toLowerCase() ||
        word != word.toUpperCase() ||
        _abbreviations.contains(word) ||
        _romanNumber.hasMatch(word) ||
        (word.length == 1 &&
            (name || (word.codeUnitAt(0) >= 65 && word.codeUnitAt(0) <= 90)))) {
      return word;
    }
    final lower = word.toLowerCase();
    final afterNameSeparator =
        name && match.start > 0 && '-+'.contains(value[match.start - 1]);
    return first || afterNameSeparator
        ? '${lower[0].toUpperCase()}${lower.substring(1)}'
        : lower;
  });
}

String readableDrugName(String value) => readableDrugText(value, name: true);

String readableManufacturer(String value) {
  final text = readableDrugText(value);
  return text.replaceFirstMapped(
    RegExp(r'''^(ООО|АО|ОАО|ПАО|ЗАО|НАО|OOO)(\s+[«"'(]*)([а-яa-zё])'''),
    (match) =>
        '${match.group(1)}${match.group(2)}${match.group(3)!.toUpperCase()}',
  );
}
