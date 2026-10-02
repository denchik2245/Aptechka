import base64
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock
from urllib.error import HTTPError

from tools.import_rls_photos import RlsClient, RlsError, import_photos, normalize_barcode

PIXEL = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jrVsAAAAASUVORK5CYII=')
GTIN = '04601669000675'


class RlsPhotoTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.output = Path(temp.name)

    def row(self, **changes):
        return {'packing_id': 95500, 'barcode': '4601669000675', 'picname': '95500.png', **changes}

    def test_exact_barcode_mapping_and_shared_picture(self):
        other = '03352712000197'
        rows = [self.row(barcode=f'4601669000675, {other}'), self.row(barcode='9999999999999', picname='other.png')]
        fetch = Mock(return_value=PIXEL)
        result = import_photos(rows, {GTIN, other}, fetch, self.output)
        self.assertEqual(result['matchedGtins'], 2)
        self.assertEqual(result['images'], 1)
        fetch.assert_called_once_with('95500.png')
        manifest = json.loads((self.output / 'manifest.json').read_text())
        self.assertEqual({item['gtin'] for item in manifest['entries']}, {GTIN, other})
        self.assertTrue((self.output / Path(manifest['entries'][0]['asset']).name).exists())
        self.assertEqual(manifest['usage'], 'demo')
        self.assertIsNone(normalize_barcode('4601669000675?foo=1'))

    def test_conflicting_images_and_non_images_preserve_previous_manifest(self):
        manifest = self.output / 'manifest.json'
        manifest.write_text('previous')
        with self.assertRaises(RlsError):
            import_photos([self.row(), self.row(picname='different.png')], {GTIN}, Mock(), self.output)
        with self.assertRaises(RlsError):
            import_photos([self.row()], {GTIN}, lambda _: b'<html>sign in</html>', self.output)
        self.assertEqual(manifest.read_text(), 'previous')

    def test_unsafe_filenames_and_missing_rights_are_rejected_before_download(self):
        fetch = Mock()
        with self.assertRaises(RlsError):
            import_photos([self.row(picname='../secret.png')], {GTIN}, fetch, self.output)
        with self.assertRaises(ValueError):
            import_photos([self.row()], {GTIN}, fetch, self.output, usage='licensed')
        fetch.assert_not_called()

    def test_access_denial_is_explicit_and_does_not_leak_credentials(self):
        client = RlsClient('private-user', 'private-password')
        client.opener = Mock()
        client.opener.open.side_effect = HTTPError('https://aurora.rlsnet.ru/api/inventory_brief', 401, 'Unauthorized', {}, None)
        with self.assertRaises(RlsError) as caught:
            client.inventory()
        self.assertIn('HTTP 401', str(caught.exception))
        self.assertNotIn('private', str(caught.exception))


if __name__ == '__main__':
    unittest.main()
