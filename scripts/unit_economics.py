#!/usr/bin/env python3
"""Illustrative arithmetic, not competitor accounts, tax advice or a live quote."""
import argparse
from decimal import Decimal, ROUND_HALF_UP
import json

D = Decimal
def calculate(minutes='30', gross_per_minute='2', host_total='17', tax_rate='0.18',
              channel_fee_rate='0.15', rtc_usd_per_1000='0.99', inr_per_usd='88',
              reserve_rate='0.02', fixed_monthly='20000'):
    vals = list(map(D, [minutes,gross_per_minute,host_total,tax_rate,channel_fee_rate,
                         rtc_usd_per_1000,inr_per_usd,reserve_rate,fixed_monthly]))
    m,p,h,t,f,r,fx,reserve,fixed=vals
    if any(not x.is_finite() or x<0 for x in vals) or m==0 or fx==0 or any(x>1 for x in [t,f,reserve]):
        raise ValueError('Inputs must be finite and nonnegative; minutes/FX > 0 and rates <= 1.')
    gross=m*p
    ex_tax=gross/(1+t)
    tax=gross-ex_tax
    channel=ex_tax*f  # Explicit model assumption: fee base is ex-tax service spend.
    participant_minutes=2*m
    rtc=participant_minutes*r/D(1000)*fx
    variable_reserve=gross*reserve
    contribution=ex_tax-h-channel-rtc-variable_reserve
    breakeven=fixed/contribution if contribution>0 else None
    result={'gross_spend':gross,'assumed_tax_component':tax,'spend_ex_tax':ex_tax,
            'host_earning':h,'assumed_channel_fee':channel,'participant_minutes':participant_minutes,
            'rtc_cost':rtc,'variable_reserve':variable_reserve,'contribution_before_fixed_costs':contribution,
            'sessions_to_cover_fixed_costs':breakeven}
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    defaults={'minutes':'30','gross_per_minute':'2','host_total':'17','tax_rate':'0.18',
              'channel_fee_rate':'0.15','rtc_usd_per_1000':'0.99','inr_per_usd':'88',
              'reserve_rate':'0.02','fixed_monthly':'20000'}
    for key,value in defaults.items():
        parser.add_argument('--'+key.replace('_','-'),default=value)
    parser.add_argument('--host-hourly', help='Listener INR per paid connected hour, overrides host total')
    args=vars(parser.parse_args())
    hourly=args.pop('host_hourly')
    if hourly is not None:
        args['host_total']=str(D(hourly)*D(args['minutes'])/60)
    result=calculate(**args)
    print(json.dumps({'assumptions':args,'results':{
       k:None if v is None else str(v.quantize(D('.01'),rounding=ROUND_HALF_UP)) for k,v in result.items()},
       'limits':'Fee/tax/FX inputs are illustrative. No CAC, salaries, host idle-time guarantees, or actual tax treatment. Two participants assumed. No competitor margin claim.'},indent=2))

if __name__=='__main__':
    main()
