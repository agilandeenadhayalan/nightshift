import { Controller,Get,Inject,Param,Query,Req,Res,UseFilters } from '@nestjs/common';
import { Request,Response } from 'express';
import { fields,object } from '../errors';
import { StaffAuthority } from './authority';
import { readStaffCookie,STAFF_COOKIE,StaffErrorFilter } from './http';
import { StaffReviewQueries } from './review-queries';

@Controller('v1/admin/listener-applications')
@UseFilters(StaffErrorFilter)
export class StaffReviewController {
  constructor(@Inject(StaffAuthority)private readonly authority:StaffAuthority,@Inject(StaffReviewQueries)private readonly reviews:StaffReviewQueries){}
  private async actor(req:Request,res:Response){
    res.setHeader('Cache-Control','no-store, private');res.setHeader('Vary','Cookie');res.setHeader('X-Content-Type-Options','nosniff');
    this.authority.origin(req.headers.origin,false);
    return this.authority.authenticate(readStaffCookie(req,STAFF_COOKIE));
  }
  @Get()async queue(@Req()req:Request,@Query()query:unknown,@Res({passthrough:true})res:Response){
    return this.reviews.queue(await this.actor(req,res),query);
  }
  @Get(':id')async detail(@Req()req:Request,@Param('id')id:string,@Query()query:unknown,@Res({passthrough:true})res:Response){
    const actor=await this.actor(req,res);fields(object(query),[]);return this.reviews.detail(actor,id);
  }
  @Get(':id/voice-sample')async sample(@Req()req:Request,@Param('id')id:string,@Query()raw:unknown,@Res()res:Response){
    const actor=await this.actor(req,res),query=object(raw);fields(query,['version']);
    const result=await this.reviews.sampleBytes(actor,id,query.version);
    res.setHeader('Content-Type','audio/wav');res.setHeader('Content-Length',result.bytes.length);
    res.setHeader('Content-Disposition','inline; filename="review-sample.wav"');res.setHeader('X-Review-Material-Version',result.materialVersion);
    // Range is deliberately ignored: a complete bounded WAV is returned.
    // End directly to avoid Express generating an ETag or turning this
    // authorized full-body response into a conditional 304.
    res.status(200).end(result.bytes);
  }
}
