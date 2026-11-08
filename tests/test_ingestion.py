"""Boundary checks for data issues that change the retail analysis."""
import sys
import unittest
from datetime import date
from decimal import Decimal
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'scripts'))
from build_bi import date_value, flag, number, unique


class IngestionChecks(unittest.TestCase):
    def test_coursework_two_digit_and_four_digit_dates(self):
        self.assertEqual(date_value('2/5/10'), date(2010, 2, 5))
        self.assertEqual(date_value('02/05/2010'), date(2010, 2, 5))

    def test_missing_markdown_is_not_reported_zero(self):
        self.assertIsNone(number('NA', nullable=True))
        self.assertEqual(number('0', nullable=True), Decimal('0'))

    def test_negative_sales_are_retained(self):
        self.assertEqual(number('-12.34'), Decimal('-12.34'))

    def test_duplicate_grain_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'duplicate keys'):
            unique([(1, 2, '2010-02-05', 10), (1, 2, '2010-02-05', 20)],
                   lambda row: row[:3], 'sales')

    def test_invalid_numeric_and_holiday_fail_loudly(self):
        for text in ('NaN', 'Infinity', 'oops'):
            with self.assertRaises(ValueError):
                number(text)
        with self.assertRaises(ValueError):
            flag('unknown')


if __name__ == '__main__':
    unittest.main()
