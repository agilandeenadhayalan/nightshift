#!/usr/bin/env python3
"""Illustrative Decimal scenarios, not competitor accounts or live provider quotes."""
import argparse
from decimal import Decimal, ROUND_HALF_UP, localcontext
import json

D = Decimal


def calculate(minutes='30', gross_per_minute='2', host_total='17', tax_rate='0.18',
              channel_fee_rate='0.15', rtc_usd_per_1000='0.99', inr_per_usd='88',
              reserve_rate='0.02', fixed_monthly='20000',
              otp_cost_per_successful_login='0', calls_per_successful_login='1',
              host_hourly=None):
    """Return unrounded INR/session values, with two connected participants.

    Gross service spend includes assumed tax. Channel fees apply to ex-tax
    spend. The caller-supplied successful-login OTP cost includes failed-send
    expense and is amortized across calls from that login. Hourly compensation
    applies only to delivered connected minutes, not online time.
    """
    vals = list(map(D, [minutes, gross_per_minute, host_total, tax_rate,
                         channel_fee_rate, rtc_usd_per_1000, inr_per_usd,
                         reserve_rate, fixed_monthly, otp_cost_per_successful_login,
                         calls_per_successful_login]))
    m, p, h, t, f, r, fx, reserve, fixed, otp, calls_per_login = vals
    if (any(not x.is_finite() or x < 0 for x in vals) or m == 0 or fx == 0
            or calls_per_login == 0 or any(x > 1 for x in [t, f, reserve])):
        raise ValueError('Inputs must be finite and nonnegative; minutes/FX/calls per login > 0 and rates <= 1.')
    hourly = None if host_hourly is None else D(host_hourly)
    if hourly is not None and (not hourly.is_finite() or hourly < 0):
        raise ValueError('Host hourly rate must be finite and nonnegative.')
    with localcontext() as context:
        context.prec = 40
        if hourly is not None:
            h = hourly * m / D(60)
        gross = m * p
        ex_tax = gross / (1 + t)
        tax = gross - ex_tax
        channel = ex_tax * f  # Explicit assumption: ex-tax service-spend fee base.
        participant_minutes = 2 * m
        rtc = participant_minutes * r / D(1000) * fx
        variable_reserve = gross * reserve
        otp_per_call = otp / calls_per_login
        contribution = ex_tax - h - channel - rtc - variable_reserve - otp_per_call
        breakeven = fixed / contribution if contribution > 0 else None
    return {'gross_spend': gross, 'assumed_tax_component': tax, 'spend_ex_tax': ex_tax,
            'host_earning': h, 'assumed_channel_fee': channel,
            'participant_minutes': participant_minutes, 'rtc_cost': rtc,
            'variable_reserve': variable_reserve, 'otp_cost_per_call': otp_per_call,
            'contribution_before_fixed_costs': contribution,
            'sessions_to_cover_fixed_costs': breakeven}


def assess(contribution):
    if contribution < 0:
        return 'REJECT_NEGATIVE_CONTRIBUTION'
    if contribution == 0:
        return 'NO_FIXED_COST_COVERAGE'
    return 'POSITIVE_BEFORE_FIXED_COSTS_NOT_LAUNCH_APPROVAL'


def scenario_matrix(**assumptions):
    """Compare three prices, two fees and two historical RTC assumptions.

    RTC inputs come from the master plan; they are not current vendor quotes.
    Duration and the remaining assumptions stay constant across the matrix.
    """
    defaults = {'minutes': '30', 'host_hourly': '500', 'tax_rate': '0.18',
                'inr_per_usd': '88', 'reserve_rate': '0.02', 'fixed_monthly': '20000',
                'otp_cost_per_successful_login': '0.50',
                'calls_per_successful_login': '5'}
    defaults.update(assumptions)
    result = []
    for media, rtc_rate in [('audio', '0.99'), ('video', '3.99')]:
        for price in ['12', '15', '20']:
            for fee in ['0.15', '0.30']:
                scenario = {**defaults, 'gross_per_minute': price,
                            'channel_fee_rate': fee, 'rtc_usd_per_1000': rtc_rate}
                values = calculate(**scenario)
                result.append({'media': media, 'assumptions': scenario,
                               'results': values,
                               'assessment': assess(values['contribution_before_fixed_costs'])})
    return result


def formatted(values):
    return {key: None if value is None else
            str(value.quantize(D('.01'), rounding=ROUND_HALF_UP))
            for key, value in values.items()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    defaults = {'minutes': '30', 'gross_per_minute': '2', 'host_total': '17',
                'tax_rate': '0.18', 'channel_fee_rate': '0.15',
                'rtc_usd_per_1000': '0.99', 'inr_per_usd': '88',
                'reserve_rate': '0.02', 'fixed_monthly': '20000',
                'otp_cost_per_successful_login': '0', 'calls_per_successful_login': '1'}
    for key, value in defaults.items():
        parser.add_argument('--' + key.replace('_', '-'), default=value)
    parser.add_argument('--host-hourly',
                        help='Listener INR per paid connected hour, overrides host total')
    parser.add_argument('--scenario-matrix', action='store_true',
                        help='Fixed comparison: INR 12/15/20, 15/30%% fees, audio/video and INR 500/hour; OTP INR 0.50 per login over five calls')
    args = vars(parser.parse_args())
    matrix = args.pop('scenario_matrix')
    limits = ('Fee/tax/FX/RTC/OTP inputs are illustrative assumptions, not live quotes or legal advice. '
              'No CAC, salaries, host idle-time guarantees, or actual tax treatment. '
              'Two participants assumed. No competitor margin claim. Negative contribution is rejected; '
              'any later subsidy needs an explicit capped owner decision.')
    if matrix:
        if args['host_hourly'] is not None or any(args[key] != value for key, value in defaults.items()):
            parser.error('--scenario-matrix uses fixed assumptions; use single-scenario flags separately')
        # The matrix is fixed for reproducibility. Sensitivity analysis uses
        # the single-scenario flags or scenario_matrix keyword arguments.
        rows = scenario_matrix()
        for row in rows:
            row['results'] = formatted(row['results'])
        print(json.dumps({'scenarios': rows, 'limits': limits}, indent=2))
        return 0
    result = calculate(**args)
    assessment = assess(result['contribution_before_fixed_costs'])
    print(json.dumps({'assumptions': args, 'results': formatted(result),
                      'assessment': assessment, 'limits': limits}, indent=2))
    return 2 if result['contribution_before_fixed_costs'] < 0 else 0


if __name__ == '__main__':
    raise SystemExit(main())
