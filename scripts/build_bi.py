#!/usr/bin/env python3
"""Validate source CSVs, run the MySQL BI model, reconcile, then export for Power BI.

Standard library only. Needs a MySQL 8+ client/server. Never opens a network API.
Raw inputs and generated exports are ignored by Git.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import re
import shutil
import subprocess
from collections import Counter
from datetime import datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = {
    'stores': 'stores.csv', 'features': 'store_features.csv',
    'store1': 'store 1.csv', 'store12': 'store 12.csv', 'store45': 'Store 45.csv',
}
EXPORTS = {
    'dim_store': 'SELECT * FROM dim_store ORDER BY store_id',
    'dim_department': 'SELECT * FROM dim_department ORDER BY department_id',
    'dim_week': 'SELECT * FROM dim_week ORDER BY week_date',
    'fact_store_week': 'SELECT * FROM bi_store_week ORDER BY store_id,week_date',
    'fact_department_week': 'SELECT * FROM bi_department_week ORDER BY store_id,department_id,week_date',
    'year_coverage': 'SELECT * FROM bi_year_coverage ORDER BY calendar_year',
}


def read_csv(path):
    with path.open(encoding='utf-8-sig', newline='') as f:
        return [{k.strip(): v.strip() for k, v in row.items()} for row in csv.DictReader(f)]


def date_value(text):
    for fmt in ('%m/%d/%Y', '%m/%d/%y', '%Y-%m-%d'):
        try:
            return datetime.strptime(text, fmt).date()
        except ValueError:
            pass
    raise ValueError(f'Unrecognized date: {text!r}')


def number(text, nullable=False):
    if nullable and text.upper() in ('', 'NA', 'NULL'):
        return None
    try:
        value = Decimal(text)
    except InvalidOperation as exc:
        raise ValueError(f'Invalid number: {text!r}') from exc
    if not value.is_finite():
        raise ValueError(f'Non-finite number: {text!r}')
    return value


def flag(text):
    if text.lower() not in ('true', 'false'):
        raise ValueError(f'Invalid holiday flag: {text!r}')
    return int(text.lower() == 'true')


def unique(rows, key, label):
    keys = [key(row) for row in rows]
    duplicates = len(keys) - len(set(keys))
    if duplicates:
        raise ValueError(f'{label}: {duplicates} duplicate keys; resolve them instead of dropping silently')


def normalize(data_dir):
    raw = {key: read_csv(data_dir / fn) for key, fn in FILES.items()}
    selected = (1, 12, 45)
    stores = [(int(r['Store']), r['Type'], int(r['Size'])) for r in raw['stores'] if int(r['Store']) in selected]
    if sorted(s[0] for s in stores) != list(selected) or any(s[2] <= 0 for s in stores):
        raise ValueError('Expected exactly the three selected stores with positive floor areas')
    sales = []
    holidays = {}
    for key, expected_store in [('store1', 1), ('store12', 12), ('store45', 45)]:
        for r in raw[key]:
            store, dept, day, holiday = int(r['Store']), int(r['Dept']), date_value(r['Date']), flag(r['IsHoliday'])
            if store != expected_store:
                raise ValueError(f'{key}: unexpected store {store}')
            if day in holidays and holidays[day] != holiday:
                raise ValueError(f'Holiday flag conflict on {day}')
            holidays[day] = holiday
            sales.append((store, dept, day, number(r['Weekly_Sales'])))
    features = []
    for r in raw['features']:
        store, day, holiday = int(r['Store']), date_value(r['Date']), flag(r['IsHoliday'])
        if store not in selected:
            raise ValueError(f'Unexpected feature store {store}')
        if day in holidays and holidays[day] != holiday:
            raise ValueError(f'Holiday flag conflict on {day}')
        holidays[day] = holiday
        markdowns = [number(r[f'MarkDown{i}'], nullable=True) for i in range(1, 6)]
        features.append((store, day, number(r['Temperature'], True), number(r['Fuel_Price'], True),
                         *markdowns, sum(x is not None for x in markdowns)))
    unique(sales, lambda r: r[:3], 'sales')
    unique(features, lambda r: r[:2], 'features')
    feature_keys = {r[:2] for r in features}
    if any((r[0], r[2]) not in feature_keys for r in sales):
        raise ValueError('A sales store-week has no corresponding feature row')
    dates = sorted(holidays)
    if any(d.weekday() != 4 for d in dates) or any((b-a).days != 7 for a,b in zip(dates,dates[1:])):
        raise ValueError('Expected contiguous Friday week labels')
    weeks = [(d, d.year, d.month, d.strftime('%Y-%m'), f'{d.year}-Q{(d.month-1)//3+1}', i+1, holidays[d])
             for i, d in enumerate(dates)]
    departments = [(d, f'Department {d}') for d in sorted({r[1] for r in sales})]
    return stores, departments, weeks, sales, features


def literal(value):
    if value is None:
        return 'NULL'
    if isinstance(value, (Decimal, int)):
        return str(value)
    # Hex strings avoid interpolation/escaping surprises from imported CSV text.
    encoded = str(value).encode('utf-8').hex()
    return f'CONVERT(0x{encoded} USING utf8mb4)'


def insert_sql(table, rows):
    for start in range(0, len(rows), 500):
        values = ',\n'.join('('+','.join(literal(x) for x in row)+')' for row in rows[start:start+500])
        yield f'INSERT INTO {table} VALUES\n{values};'


class MySQL:
    def __init__(self, args):
        executable = shutil.which(args.mysql) or args.mysql
        self.command = [executable]
        # MySQL requires defaults-extra-file as the first option. Never print its contents.
        if args.defaults_file:
            self.command += ['--defaults-extra-file='+str(args.defaults_file.resolve())]
        else:
            self.command += ['--no-defaults']
        self.command += ['--user='+args.user, '--batch', '--raw', '--default-character-set=utf8mb4']
        if args.socket:
            self.command += ['--protocol=SOCKET', '--socket='+str(args.socket)]
        else:
            self.command += ['--protocol=TCP', '--host='+args.host, '--port='+str(args.port)]
        self.database = args.database

    def run(self, sql, database=True):
        command = self.command + ([self.database] if database else [])
        result = subprocess.run(command, input=sql, capture_output=True, text=True, check=False)
        if result.returncode:
            raise RuntimeError(result.stderr.strip())
        return result.stdout

    def rows(self, sql, database=True):
        return list(csv.DictReader(io.StringIO(self.run(sql, database)), delimiter='\t'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data-dir', required=True, type=Path)
    parser.add_argument('--database', default='walmart_portfolio_bi')
    parser.add_argument('--mysql', default='mysql')
    parser.add_argument('--user', default='root')
    parser.add_argument('--host', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=3306)
    parser.add_argument('--socket', type=Path)
    parser.add_argument('--defaults-file', type=Path, help='Local MySQL client config; never committed')
    parser.add_argument('--replace', action='store_true', help='Replace tables only in this dedicated BI database')
    parser.add_argument('--output-dir', type=Path, default=ROOT/'data'/'exports')
    args = parser.parse_args()
    # Scope destructive refreshes to names identifying this project's BI database.
    if not re.fullmatch(r'walmart_[a-z0-9_]*bi', args.database):
        parser.error('Use a dedicated database named walmart_<name>bi, e.g. walmart_portfolio_bi')
    stores, departments, weeks, sales, features = normalize(args.data_dir)
    db = MySQL(args)
    db.run(f'CREATE DATABASE IF NOT EXISTS `{args.database}` CHARACTER SET utf8mb4;', False)
    existing = db.rows('SHOW TABLES;')
    if existing and not args.replace:
        raise RuntimeError('Database is not empty. Use --replace only for the dedicated BI database.')
    db.run((ROOT/'sql/bi/01_schema.sql').read_text())
    tables = ['fact_department_week', 'fact_store_features', 'dim_department', 'dim_week', 'dim_store']
    statements = ['START TRANSACTION;'] + [f'DELETE FROM {table};' for table in tables]
    for table, rows in [('dim_store',stores), ('dim_department',departments), ('dim_week',weeks),
                        ('fact_department_week',sales), ('fact_store_features',features)]:
        statements.extend(insert_sql(table, rows))
    statements.append('COMMIT;')
    db.run('\n'.join(statements))
    db.run((ROOT/'sql/bi/02_views.sql').read_text())
    checks = db.rows((ROOT/'sql/bi/04_quality_checks.sql').read_text())
    if any(Decimal(row['issue_count']) != 0 for row in checks):
        raise RuntimeError('SQL quality checks failed: '+json.dumps(checks))
    original_total = sum((r[3] for r in sales), Decimal('0'))
    sql_total = Decimal(db.rows('SELECT SUM(weekly_sales) AS total FROM bi_store_week;')[0]['total'])
    if original_total != sql_total:
        raise RuntimeError(f'Raw-to-SQL reconciliation failed: {original_total} != {sql_total}')
    args.output_dir.mkdir(parents=True, exist_ok=True)
    export_counts = {}
    for name, query in EXPORTS.items():
        rows = db.rows(query)
        if not rows:
            raise RuntimeError('Empty export: '+name)
        with (args.output_dir/(name+'.csv')).open('w', encoding='utf-8-sig', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows({k: '' if v == 'NULL' else v for k,v in row.items()} for row in rows)
        export_counts[name] = len(rows)
    # Verify the persisted handoff, not only the in-memory query response.
    exported_total = sum((number(r['weekly_sales']) for r in read_csv(args.output_dir/'fact_store_week.csv')), Decimal('0'))
    if exported_total != original_total:
        raise RuntimeError('Persisted BI export does not reconcile to raw sales')
    sale_dates = sorted({r[2] for r in sales})
    source_manifest = {fn: {'sha256': hashlib.sha256((args.data_dir/fn).read_bytes()).hexdigest(),
                            'bytes': (args.data_dir/fn).stat().st_size} for fn in FILES.values()}
    profile = {
        'status': 'passed', 'source_files': source_manifest,
        'sales_rows': len(sales), 'sales_total': str(original_total),
        'sales_first_week': str(sale_dates[0]), 'sales_last_week': str(sale_dates[-1]),
        'sales_weeks_by_year': dict(Counter(d.year for d in sale_dates)),
        'negative_sales_rows_retained': sum(r[3] < 0 for r in sales),
        'features_rows': len(features), 'feature_weeks_without_sales': len(features)-len({(r[0],r[2]) for r in sales}),
        'all_markdowns_missing_store_weeks': sum(r[-1] == 0 for r in features),
        'sql_checks': checks, 'export_rows': export_counts,
        'raw_sql_export_total_reconciled': True,
        'mysql_version': db.rows('SELECT VERSION() AS version;')[0]['version'],
    }
    artifact_dir = ROOT/'artifacts'
    artifact_dir.mkdir(exist_ok=True)
    (artifact_dir/'validation.json').write_text(json.dumps(profile, indent=2)+'\n')
    (artifact_dir/'business_query_results.tsv').write_text(db.run((ROOT/'sql/bi/03_business_queries.sql').read_text()))
    print(json.dumps({k: v for k,v in profile.items() if k != 'source_files'}, indent=2))


if __name__ == '__main__':
    main()
