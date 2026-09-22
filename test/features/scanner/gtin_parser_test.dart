import 'package:aptechka/features/scanner/domain/gtin_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GtinParser', () {
    test('normalizes EAN-13 to GTIN-14', () {
      expect(GtinParser.parse('4601234567890'), '04601234567890');
    });

    test('reads application identifier 01 from Data Matrix', () {
      expect(
        GtinParser.parse(']d2010460123456789021ABC12391ABCD92XYZ'),
        '04601234567890',
      );
    });

    test('returns null for unsupported contents', () {
      expect(GtinParser.parse('https://example.com'), isNull);
    });
  });
}
