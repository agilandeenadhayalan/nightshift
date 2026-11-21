import {Body,Controller,Get,HttpCode,Inject,Param,Post,Query,Req,Res,UseFilters} from '@nestjs/common';
import {Request,Response} from 'express';
import {fields,object,requireThat} from '../errors';
import {StaffAuthority} from './authority';
import {readStaffCookie,STAFF_COOKIE,StaffErrorFilter} from './http';
import {StaffReviewDecisions} from './review-decisions';

@Controller('v1/admin')
@UseFilters(StaffErrorFilter)
export class StaffReviewDecisionController {
  constructor(@Inject(StaffAuthority)private readonly authority:StaffAuthority,@Inject(StaffReviewDecisions)private readonly decisions:StaffReviewDecisions){}
  private async actor(req:Request,res:Response,mutation=false){
    res.setHeader('Cache-Control','no-store');res.setHeader('Vary','Cookie');res.setHeader('X-Content-Type-Options','nosniff');
    const cookie=readStaffCookie(req,STAFF_COOKIE);
    if(mutation)this.authority.checkMutation(cookie,req.headers['x-csrf-token'],req.headers.origin);
    else this.authority.origin(req.headers.origin,false);
    return this.authority.authenticate(cookie);
  }
  @Get('listener-review-policy')async policy(@Req()req:Request,@Query()query:unknown,@Res({passthrough:true})res:Response){
    const actor=await this.actor(req,res);fields(object(query),[]);return this.decisions.describe(actor);
  }
  @Post('listener-applications/:id/decisions')@HttpCode(200)
  async decide(@Req()req:Request,@Param('id')id:string,@Body()body:unknown,@Query()query:unknown,@Res({passthrough:true})res:Response){
    const actor=await this.actor(req,res,true);fields(object(query),[]);
    requireThat(req.headers['content-type']?.split(';')[0]?.trim()==='application/json',400,'INVALID_BODY','Use a JSON request.');
    return this.decisions.decide(actor,id,body,req.headers['idempotency-key']);
  }
  @Get('listener-applications/:id/decision-receipt')
  async receipt(@Req()req:Request,@Param('id')id:string,@Query()query:unknown,@Res({passthrough:true})res:Response){
    const actor=await this.actor(req,res);fields(object(query),[]);return this.decisions.receipt(actor,id,req.headers['idempotency-key']);
  }
}
