"""Import authorised RLS Aurora package photos without sending user inventories.

Credentials come only from RLS_USERNAME/RLS_PASSWORD. See docs/rls-integration.md.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import HTTPRedirectHandler, Request, build_opener

BASE = 'https://aurora.rlsnet.ru/api/'
PHOTO_DIR = Path('assets/drug_photos')


class RlsError(Exception):
    pass


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Never forward the supplier's Basic credentials to a redirect target.
        return None


class RlsClient:
    def __init__(self, username, password):
        if not username or not password:
            raise RlsError('Set RLS_USERNAME and RLS_PASSWORD in the environment')
        self.authorization = 'Basic ' + base64.b64encode(f'{username}:{password}'.encode()).decode()
        self.opener = build_opener(NoRedirect())
        self.last_request = 0.0

    def get(self, method, **query):
        if method not in ('inventory_brief', 'inventory_pics'):
            raise ValueError('Unsupported RLS method')
        delay = 1 - (time.monotonic() - self.last_request)
        if delay > 0:
            time.sleep(delay)
        self.last_request = time.monotonic()
        request = Request(BASE + method + '?' + urlencode(query), headers={
            'Authorization': self.authorization, 'Accept': 'application/json',
            'User-Agent': 'AptechkaPrototypeIntegration/0.1',
        })
        try:
            with self.opener.open(request, timeout=30) as response:
                limit = 8 * 1024 * 1024
                body = response.read(limit + 1)
                if not body or len(body) > limit:
                    raise RlsError('Empty or oversized RLS response')
                declared = response.headers.get('Content-Length')
                if declared and int(declared) != len(body):
                    raise RlsError('Incomplete RLS response')
                return body
        except HTTPError as error:
            if error.code in (401, 403):
                raise RlsError(f'RLS denied access (HTTP {error.code}); request access from the supplier') from None
            raise RlsError(f'RLS request failed (HTTP {error.code})') from None
        except (URLError, TimeoutError, OSError):
            raise RlsError('RLS connection failed') from None

    def inventory(self, gtin=None):
        # Only a public catalog GTIN or the official probe ID reaches RLS.
        query = {'ean': gtin} if gtin else {'packing_id': 95500}
        rows = json.loads(self.get('inventory_brief', **query))
        if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
            raise RlsError('Unexpected RLS inventory format')
        return rows


def normalize_barcode(value):
    if not isinstance(value, str) or not re.fullmatch(r'\d{8}|\d{12,14}', value.strip()):
        return None
    return value.strip().zfill(14)


def image_extension(body):
    if body.startswith(b'\x89PNG\r\n\x1a\n'):
        return 'png'
    if body.startswith(b'\xff\xd8\xff'):
        return 'jpg'
    if body.startswith((b'GIF87a', b'GIF89a')):
        return 'gif'
    if body.startswith(b'RIFF') and body[8:12] == b'WEBP':
        return 'webp'
    raise RlsError('RLS did not return a supported image')


def import_photos(rows, catalog_gtins, fetch_image, output, *, usage='demo', rights_reference=''):
    if usage not in ('demo', 'licensed') or (usage == 'licensed' and not rights_reference.strip()):
        raise ValueError('Licensed imports require a rights reference')
    candidates = {}
    for row in rows:
        picname = row.get('picname')
        if not picname:
            continue
        if not isinstance(picname, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,99}', picname):
            raise RlsError('Invalid RLS picture name')
        if '..' in picname:
            raise RlsError('Invalid RLS picture name')
        packing = row.get('packing_id')
        if not isinstance(packing, int) or isinstance(packing, bool) or packing <= 0:
            raise RlsError('Invalid RLS packing ID')
        barcodes = re.split(r'[,;\s]+', row.get('barcode') or '')
        for value in barcodes:
            gtin = normalize_barcode(value)
            if gtin in catalog_gtins:
                candidates.setdefault(gtin, {})[picname] = row
    # Different images for the same barcode are ambiguous. Do not pick one by name.
    exact = {gtin: next(iter(options.values())) for gtin, options in candidates.items() if len(options) == 1}
    if not exact:
        raise RlsError('No unambiguous photos match the MDLP catalog; existing manifest preserved')
    cache, entries = {}, []
    for gtin, row in sorted(exact.items()):
        picname = row['picname']
        if picname not in cache:
            body = fetch_image(picname)
            if not body or len(body) > 8 * 1024 * 1024:
                raise RlsError('Empty or oversized image')
            suffix = image_extension(body)
            filename = hashlib.sha256(body).hexdigest() + '.' + suffix
            cache[picname] = (filename, body)
        filename, _ = cache[picname]
        entries.append({
            'gtin': gtin, 'asset': f'assets/drug_photos/{filename}',
            'packingId': row['packing_id'], 'picname': picname,
            'sourceUrl': BASE + 'inventory_pics?' + urlencode({'picname': picname}),
            'sourceUpdatedAt': row.get('actdate') or '',
        })
    manifest = {
        'schemaVersion': 1, 'source': 'РЛС Аврора', 'usage': usage,
        'rightsReference': rights_reference.strip(),
        'importedAt': datetime.now(timezone.utc).isoformat(),
        'entries': entries,
    }
    # All responses validated before publishing the manifest. Old assets remain usable.
    output.mkdir(parents=True, exist_ok=True)
    for filename, body in cache.values():
        path = output / filename
        temporary = path.with_suffix(path.suffix + '.tmp')
        temporary.write_bytes(body)
        temporary.replace(path)
    temporary = output / 'manifest.json.tmp'
    temporary.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    temporary.replace(output / 'manifest.json')
    return {'matchedGtins': len(entries), 'images': len(cache),
            'ambiguousGtins': len(candidates) - len(exact), 'usage': usage}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--probe', action='store_true', help='Check the official example without modifying assets')
    mode.add_argument('--gtin', action='append', help='MDLP public catalog GTIN; repeat for several packages')
    mode.add_argument('--inventory', type=Path, help='Authorised inventory_brief JSON export (array)')
    parser.add_argument('--usage', choices=['demo', 'licensed'], default='demo')
    parser.add_argument('--rights-reference', default='', help='Reference to the permission/contract for licensed usage')
    parser.add_argument('--catalog', type=Path, default=Path('assets/drug_catalog/mdlp_catalog.json'))
    parser.add_argument('--output', type=Path, default=PHOTO_DIR)
    args = parser.parse_args()
    try:
        client = RlsClient(os.environ.get('RLS_USERNAME'), os.environ.get('RLS_PASSWORD'))
        if args.probe:
            rows = client.inventory()
            photos = sum(bool(row.get('picname')) for row in rows)
            print(json.dumps({'connected': True, 'rows': len(rows), 'rowsWithPhoto': photos}))
            return
        if args.usage == 'licensed' and not args.rights_reference.strip():
            parser.error('--rights-reference is required for licensed usage')
        data = json.loads(args.catalog.read_text(encoding='utf-8'))
        gtin_column = data['fields'].index('gtin')
        gtins = {data['strings'][row[gtin_column]] for row in data['entries']}
        if args.inventory:
            rows = json.loads(args.inventory.read_text(encoding='utf-8-sig'))
            if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
                raise RlsError('Inventory export must be a JSON array of records')
        else:
            requested = list(dict.fromkeys(args.gtin))
            if any(gtin not in gtins for gtin in requested):
                raise RlsError('All requested GTINs must exist in the public MDLP catalog')
            rows = []
            for gtin in requested:
                matches = client.inventory(gtin)
                if not matches and gtin.startswith('0'):
                    matches = client.inventory(gtin[1:])
                # A mismatched response must never add a different package's image.
                rows.extend(row for row in matches if gtin in {
                    normalize_barcode(value) for value in re.split(r'[,;\s]+', row.get('barcode') or '')
                })
        result = import_photos(rows, gtins, lambda pic: client.get('inventory_pics', picname=pic),
                               args.output, usage=args.usage, rights_reference=args.rights_reference)
        print(json.dumps(result, ensure_ascii=False))
    except (RlsError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f'{error}\n')


if __name__ == '__main__':
    main()
