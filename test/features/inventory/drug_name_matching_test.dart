import 'package:aptechka/features/inventory/domain/drug_name_matching.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'allows substitution, missing/extra letters, transposition and two typos',
    () {
      for (final query in [
        'ибупрафен',
        'ибупрофн',
        'ибуппрофен',
        'ибупорфен',
      ]) {
        expect(drugNameTypoDistance('ибупрофен', query), 1, reason: query);
      }
      expect(drugNameTypoDistance('ибупрофен', 'ибупрафн'), 2);
      expect(drugNameTypoDistance('ибупрофен акос', 'ибупраф'), 1);
      expect(drugNameTypoDistance('ибупрофен', 'абупрофен'), 1);
    },
  );

  test('short queries, digits and unrelated names are not corrected', () {
    expect(drugNameTypoDistance('ибупрофен', 'ибу'), isNull);
    expect(drugNameTypoDistance('нурофен', 'рофен'), isNull);
    expect(drugNameTypoDistance('ибупрофен', 'лоратадин'), isNull);
    expect(drugNameTypoDistance('препарат 200', 'препарат 400'), isNull);
    expect(drugNameTypoDistance('ибупрофен', 'абапрафан'), isNull);
  });
}
