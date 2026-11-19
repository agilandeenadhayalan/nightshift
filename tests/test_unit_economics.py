"""Financial scenario invariants; no live rates, purchases or provider access."""
from decimal import Decimal, localcontext
from pathlib import Path
import importlib.util
import json
import subprocess
import sys
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts' / 'unit_economics.py'
SPEC = importlib.util.spec_from_file_location('unit_economics', SCRIPT)
economics = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(economics)
D = Decimal


class EconomicsTests(unittest.TestCase):
    def test_historical_example_is_preserved(self):
        result = economics.calculate()
        displayed = economics.formatted(result)
        self.assertEqual(displayed['gross_spend'], '60.00')
        self.assertEqual(displayed['host_earning'], '17.00')
        self.assertEqual(displayed['rtc_cost'], '5.23')
        self.assertEqual(displayed['contribution_before_fixed_costs'], '19.79')
        self.assertEqual(result['participant_minutes'], D('60'))
        self.assertEqual(result['otp_cost_per_call'], D('0'))

    def test_six_paid_minutes_at_hourly_proposal_earn_fifty(self):
        result = economics.calculate(minutes='6', host_hourly='500')
        self.assertEqual(result['host_earning'], D('50'))
        self.assertEqual(result['participant_minutes'], D('12'))

    def test_otp_cost_is_amortized_per_successful_login(self):
        baseline = economics.calculate()
        result = economics.calculate(otp_cost_per_successful_login='2.50',
                                     calls_per_successful_login='5')
        self.assertEqual(result['otp_cost_per_call'], D('0.50'))
        self.assertEqual(baseline['contribution_before_fixed_costs'] -
                         result['contribution_before_fixed_costs'], D('0.50'))

    def test_matrix_has_all_twelve_combinations(self):
        rows = economics.scenario_matrix()
        keys = {(row['media'], row['assumptions']['gross_per_minute'],
                 row['assumptions']['channel_fee_rate']) for row in rows}
        self.assertEqual(len(keys), 12)
        for row in rows:
            self.assertEqual(row['results']['host_earning'], D('250'))
            self.assertEqual(row['results']['otp_cost_per_call'], D('0.1'))
            self.assertEqual(row['results']['participant_minutes'], D('60'))

    def test_high_fee_low_price_is_rejected_and_not_break_even(self):
        rows = economics.scenario_matrix()
        low = next(row for row in rows if row['media'] == 'audio' and
                   row['assumptions']['gross_per_minute'] == '12' and
                   row['assumptions']['channel_fee_rate'] == '0.30')
        self.assertLess(low['results']['contribution_before_fixed_costs'], 0)
        self.assertEqual(low['assessment'], 'REJECT_NEGATIVE_CONTRIBUTION')
        self.assertIsNone(low['results']['sessions_to_cover_fixed_costs'])

    def test_video_adds_two_participant_media_cost(self):
        rows = economics.scenario_matrix()
        audio, video = rows[0], rows[6]
        media_difference = D('60') * D('3.00') / D('1000') * D('88')
        self.assertEqual(video['results']['rtc_cost'] - audio['results']['rtc_cost'],
                         media_difference)
        self.assertEqual(audio['results']['contribution_before_fixed_costs'] -
                         video['results']['contribution_before_fixed_costs'], media_difference)

    def test_invalid_inputs_are_rejected(self):
        for inputs in [{'minutes': '0'}, {'minutes': 'NaN'}, {'inr_per_usd': '0'},
                       {'channel_fee_rate': '1.01'}, {'tax_rate': '-0.01'},
                       {'calls_per_successful_login': '0'},
                       {'otp_cost_per_successful_login': 'Infinity'},
                       {'host_hourly': '-1'}, {'host_hourly': 'NaN'}]:
            with self.subTest(inputs=inputs), self.assertRaises(ValueError):
                economics.calculate(**inputs)

    def test_fixed_cost_break_even_only_exists_when_contribution_positive(self):
        small = economics.calculate(fixed_monthly='10000')
        large = economics.calculate(fixed_monthly='20000')
        with localcontext() as context:
            context.prec = 40
            self.assertAlmostEqual(large['sessions_to_cover_fixed_costs'],
                                   small['sessions_to_cover_fixed_costs'] * 2, places=30)
        zero = economics.calculate(gross_per_minute='0', host_total='0',
                                   rtc_usd_per_1000='0')
        self.assertEqual(economics.assess(zero['contribution_before_fixed_costs']),
                         'NO_FIXED_COST_COVERAGE')
        self.assertIsNone(zero['sessions_to_cover_fixed_costs'])

    def test_cli_rejects_negative_contribution_with_machine_readable_result(self):
        completed = subprocess.run([sys.executable, str(SCRIPT), '--gross-per-minute',
                                    '12', '--host-hourly', '500', '--channel-fee-rate',
                                    '0.30'], capture_output=True, text=True, check=False)
        self.assertEqual(completed.returncode, 2)
        self.assertEqual(json.loads(completed.stdout)['assessment'],
                         'REJECT_NEGATIVE_CONTRIBUTION')

    def test_fixed_matrix_does_not_silently_ignore_sensitivity_flags(self):
        completed = subprocess.run([sys.executable, str(SCRIPT), '--scenario-matrix',
                                    '--minutes', '6'], capture_output=True, text=True,
                                   check=False)
        self.assertEqual(completed.returncode, 2)
        self.assertIn('uses fixed assumptions', completed.stderr)


if __name__ == '__main__':
    unittest.main()
