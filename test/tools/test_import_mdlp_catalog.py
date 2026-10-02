import csv
import tempfile
import unittest
from pathlib import Path

from tools.import_mdlp_catalog import import_catalog, REQUIRED, checked_url

class ImportTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.path = Path(temp.name) / 'source.csv'
        self.passport = {'meta': [
            {'ident': 'creator', 'value': 'Оператор-ЦРПТ'},
            {'ident': 'modified', 'value': '2026-10-01'},
            {'ident': 'valid', 'value': '2026-10-01'},
        ], 'data': [{'name': 'data-20261001-structure-20240611.csv',
            'url': 'https://датамаркет.честныйзнак.рф/bi/api/opendata/7731376812-MDLPGtins/data/data-20261001-structure-20240611.csv'}]}

    def write(self, rows):
        with self.path.open('w', encoding='utf-8-sig', newline='') as file:
            writer = csv.DictWriter(file, sorted(REQUIRED | {'prod_d_norm_name'}))
            writer.writeheader()
            writer.writerows(rows)

    def row(self, gtin='04601669000675', **changes):
        return {**dict.fromkeys(REQUIRED, ''), 'gtin': gtin, 'prod_sell_name': 'Цитрамон П',
            'prod_name': 'Вещество 1+Вещество 2', 'prod_form_name': 'ТАБЛЕТКИ',
            'prod_d_name': '27.3 мг', 'prod_d_norm_name': '30 мг',
            'prod_pack_1_name': 'БЛИСТЕР', 'prod_pack_1_desc': 'По 10 шт',
            'glf_name': 'Производитель', 'reg_status': 'Действующий', **changes}

    def test_raw_dose_and_complete_rows_are_preserved(self):
        self.write([self.row(), self.row('03352712000197', prod_d_name='~', reg_status='Недействующий')])
        result = import_catalog(self.path, self.passport)
        rows = [[result['strings'][cell] for cell in row] for row in result['entries']]
        self.assertEqual(rows[0][4], '27.3 мг')
        self.assertEqual(rows[1][4], '')
        self.assertEqual(rows[1][-1], 'Недействующий')
        self.assertEqual(result['metadata']['recordCount'], 2)
        self.assertEqual(result['metadata']['sourceBytes'], self.path.stat().st_size)
        self.assertEqual(len(result['metadata']['sourceSha256']), 64)

    def test_invalid_schema_or_duplicate_gtin_cannot_replace_full_snapshot(self):
        self.write([self.row(), self.row()])
        with self.assertRaises(ValueError): import_catalog(self.path, self.passport)
        self.path.write_text('gtin,name\n123,Препарат\n')
        with self.assertRaises(ValueError): import_catalog(self.path, self.passport)
        with self.assertRaises(ValueError): checked_url('https://attacker.invalid/data.csv')
        with self.assertRaises(ValueError): checked_url('http://датамаркет.честныйзнак.рф/bi/api/opendata/7731376812-MDLPGtins/data/test.csv')

if __name__ == '__main__':
    unittest.main()
