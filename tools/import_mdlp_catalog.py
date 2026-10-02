"""Import the complete public MDLP GTIN snapshot as a compact offline asset.

No accounts, medicine inventories or user queries are sent to the publisher.
Only the publisher's declared versioned CSV is accepted. See docs/drug-catalog.md.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import tempfile
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit
from urllib.request import urlopen

HOST = 'xn--80aaani3am7aog.xn--80ajghhoc2aj1c8b.xn--p1ai'
BASE = f'https://{HOST}/bi/api/opendata/7731376812-MDLPGtins'
PASSPORT = 'https://датамаркет.честныйзнак.рф/bi/opendata/7731376812-MDLPGtins'
FIELDS = ['gtin', 'name', 'activeIngredient', 'form', 'dosage', 'unit',
          'manufacturer', 'packageDescription', 'registrationId', 'registrationStatus']
REQUIRED = {'gtin', 'prod_sell_name', 'prod_name', 'prod_form_name', 'prod_d_name',
            'prod_pack_1_desc', 'prod_pack_1_name', 'glf_name', 'reg_id', 'reg_status'}


def clean(value):
    value = re.sub(r'\s+', ' ', value or '').strip()
    return '' if value in ('~', '-', '—') else value


def unit_for(form, package):
    # A count unit, NOT a dose or an assumed quantity in the user's package.
    form, package = form.upper(), package.upper()
    if form.startswith('ТАБЛЕТКИ'):
        return 'таблеток'
    if form.startswith('КАПСУЛЫ'):
        return 'капсул'
    if package.startswith('АМПУЛ'):
        return 'ампул'
    if package.startswith('ФЛАКОН'):
        return 'флаконов'
    return 'шт.'


def checked_url(value):
    parsed = urlsplit(value)
    host = (parsed.hostname or '').encode('idna').decode()
    if parsed.scheme != 'https' or host != HOST or parsed.port not in (None, 443):
        raise ValueError('Only the official HTTPS publisher is accepted')
    if not parsed.path.startswith('/bi/api/opendata/7731376812-MDLPGtins/'):
        raise ValueError('Unexpected source path')
    return urlunsplit(('https', host, parsed.path, parsed.query, ''))


def download(url, target):
    size = 0
    with urlopen(checked_url(url), timeout=45) as response, target.open('wb') as output:
        checked_url(response.url)
        while chunk := response.read(1024 * 1024):
            size += len(chunk)
            if size > 256 * 1024 * 1024:
                raise ValueError('Source exceeds 256 MiB')
            output.write(chunk)
    return size


def import_catalog(source: Path, passport: dict):
    metadata = {item['ident']: item.get('value', '') for item in passport['meta']}
    latest = passport['data'][0]
    if not re.fullmatch(r'data-\d{8}-structure-\d{8}\.csv', latest['name']):
        raise ValueError('Unexpected version name')
    checked_url(latest['url'])
    pool, indexes, entries, seen_gtins, names, statuses = [], {}, [], set(), set(), {}

    def intern(value):
        if value not in indexes:
            indexes[value] = len(pool)
            pool.append(value)
        return indexes[value]

    with source.open(encoding='utf-8-sig', newline='') as input_file:
        reader = csv.DictReader(input_file)
        if not REQUIRED.issubset(reader.fieldnames or []):
            raise ValueError('Required columns are missing; source schema changed')
        for row in reader:
            gtin = clean(row['gtin'])
            if not re.fullmatch(r'\d{14}', gtin) or gtin in seen_gtins:
                raise ValueError('Invalid or repeated GTIN; import aborted')
            name = clean(row['prod_sell_name'])
            if not name:
                raise ValueError('Missing trade name; import aborted')
            form = clean(row['prod_form_name'])
            package = clean(row['prod_pack_1_desc'])
            status = clean(row['reg_status'])
            values = [gtin, name, clean(row['prod_name']), form,
                      clean(row['prod_d_name']), unit_for(form, row['prod_pack_1_name']),
                      clean(row['glf_name']), package, clean(row['reg_id']), status]
            entries.append([intern(value) for value in values])
            seen_gtins.add(gtin)
            names.add(name.casefold())
            statuses[status] = statuses.get(status, 0) + 1

    if not entries:
        raise ValueError('Empty source; existing asset will not be replaced')
    digest = hashlib.sha256()
    with source.open('rb') as input_file:
        while chunk := input_file.read(1024 * 1024):
            digest.update(chunk)
    return {'schemaVersion': 1, 'fields': FIELDS, 'metadata': {
        'identifier': '7731376812-MDLPGtins', 'publisher': metadata['creator'],
        'sourceUrl': PASSPORT, 'dataUrl': latest['url'], 'fileName': latest['name'],
        'modified': metadata['modified'], 'validDate': metadata['valid'],
        'sourceSha256': digest.hexdigest(), 'sourceBytes': source.stat().st_size,
        'recordCount': len(entries), 'tradeNameCount': len(names), 'statuses': statuses,
        'coverage': 'Complete publisher snapshot of medicines subject to mandatory marking; not every GRLS registration',
        'doseField': 'prod_d_name', 'formField': 'prod_form_name',
    }, 'strings': pool, 'entries': entries}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--csv', type=Path, help='Use an already downloaded official versioned CSV')
    parser.add_argument('--metadata', type=Path, help='Matching official passport JSON')
    parser.add_argument('--output', type=Path, default=Path('assets/drug_catalog/mdlp_catalog.json'))
    args = parser.parse_args()
    if bool(args.csv) != bool(args.metadata):
        parser.error('--csv and --metadata must be provided together')
    with tempfile.TemporaryDirectory(prefix='aptechka-catalog-') as temp:
        if args.metadata:
            passport = json.loads(args.metadata.read_text())
            source = args.csv
        else:
            with urlopen(BASE, timeout=45) as response:
                passport = json.load(response)
            source = Path(temp) / passport['data'][0]['name']
            download(passport['data'][0]['url'], source)
        result = import_catalog(source, passport)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        # Validate before replacing the existing complete snapshot.
        temporary = args.output.with_suffix('.json.tmp')
        temporary.write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
        temporary.replace(args.output)
        manifest = args.output.with_name('manifest.json')
        manifest.write_text(json.dumps(result['metadata'], ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(json.dumps({'records': result['metadata']['recordCount'],
                          'tradeNames': result['metadata']['tradeNameCount'],
                          'validDate': result['metadata']['validDate'],
                          'assetBytes': args.output.stat().st_size}, ensure_ascii=False))


if __name__ == '__main__':
    main()
