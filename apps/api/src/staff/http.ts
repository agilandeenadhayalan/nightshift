import { ArgumentsHost, Body, Catch, Controller, ExceptionFilter, Get, HttpCode, HttpException, Inject, Post, Req, Res, UseFilters } from '@nestjs/common';
import { Request, Response } from 'express';
import { randomUUID } from 'node:crypto';
import { ApiError, fields, object, requireThat } from '../errors';
import { StaffAuthority } from './authority';

export const STAFF_COOKIE='__Host-nightshift_staff',STAFF_CHALLENGE_COOKIE='__Host-nightshift_staff_challenge';
function readCookie(req:Request,name:string){
  const matches=(req.headers.cookie??'').split(';').map(v=>v.trim()).filter(v=>v.startsWith(`${name}=`));
  requireThat(matches.length<=1,401,'STAFF_UNAUTHENTICATED','Sign in to staff access again.');
  return matches[0]?.slice(name.length+1);
}
function cookie(name:string,value:string,maxAge:number){return `${name}=${value}; Path=/; Max-Age=${maxAge}; Secure; HttpOnly; SameSite=Strict`;}
function headers(res:Response){res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');}
function bearer(req:Request){const value=req.headers.authorization;return typeof value==='string'&&value.startsWith('Bearer ')?value.slice(7):undefined;}
function json(req:Request,body:unknown){
  requireThat(req.headers['content-type']?.split(';')[0]?.trim()==='application/json',400,'INVALID_BODY','Use a JSON request.');
  return object(body);
}
@Catch()
export class StaffErrorFilter implements ExceptionFilter{
  catch(error:unknown,host:ArgumentsHost){
    const res=host.switchToHttp().getResponse<Response>();headers(res);
    const req=host.switchToHttp().getRequest<Request&{requestId?:string}>(),requestId=req.requestId??randomUUID();
    res.setHeader('X-Request-Id',requestId);
    const known=error instanceof ApiError,status=known?error.status:error instanceof HttpException?error.getStatus():503;
    res.status(status).json({error:{code:known?error.code:'SERVICE_UNAVAILABLE',message:known?error.message:'Staff access is temporarily unavailable.'},requestId});
  }
}
@Controller('v1/admin')
@UseFilters(StaffErrorFilter)
export class StaffController{
  constructor(@Inject(StaffAuthority) private readonly authority:StaffAuthority){}
  @Get('auth/status') status(@Res({passthrough:true})res:Response){headers(res);return this.authority.status();}
  @Post('auth/challenge') @HttpCode(200)
  async challenge(@Req()req:Request,@Body()body:unknown,@Res({passthrough:true})res:Response){
    headers(res);this.authority.origin(req.headers.origin);fields(json(req,body),[]);
    const result=await this.authority.challenge(req.headers.origin,req.ip??'unknown',bearer(req));
    res.setHeader('Set-Cookie',cookie(STAFF_CHALLENGE_COOKIE,result.cookie,result.maxAgeSeconds));
    return {csrfToken:result.csrfToken,expiresAt:result.expiresAt};
  }
  @Post('auth/exchange') @HttpCode(200)
  async exchange(@Req()req:Request,@Body()body:unknown,@Res({passthrough:true})res:Response){
    headers(res);this.authority.origin(req.headers.origin);json(req,body);
    const result=await this.authority.exchange(body,req.headers.origin,readCookie(req,STAFF_CHALLENGE_COOKIE),req.headers['x-csrf-token'],bearer(req));
    res.setHeader('Set-Cookie',[cookie(STAFF_COOKIE,result.cookie,result.maxAgeSeconds),cookie(STAFF_CHALLENGE_COOKIE,'',0)]);
    return result.view;
  }
  @Post('access-requests') @HttpCode(200)
  async accessRequest(@Req()req:Request,@Body()body:unknown,@Res({passthrough:true})res:Response){
    headers(res);this.authority.origin(req.headers.origin);fields(json(req,body),[]);return this.authority.accessRequest(bearer(req),true);
  }
  @Get('access-requests/current')
  async currentRequest(@Req()req:Request,@Res({passthrough:true})res:Response){
    headers(res);this.authority.origin(req.headers.origin);return this.authority.accessRequest(bearer(req),false);
  }
  @Get('session') async session(@Req()req:Request,@Res({passthrough:true})res:Response){
    headers(res);this.authority.origin(req.headers.origin,false);return this.authority.session(readCookie(req,STAFF_COOKIE),req.headers.origin);
  }
  @Post('auth/logout') @HttpCode(200)
  async logout(@Req()req:Request,@Body()body:unknown,@Res({passthrough:true})res:Response){
    headers(res);this.authority.origin(req.headers.origin);fields(json(req,body),[]);
    const result=await this.authority.logout(readCookie(req,STAFF_COOKIE),req.headers['x-csrf-token'],req.headers.origin);
    res.setHeader('Set-Cookie',[cookie(STAFF_COOKIE,'',0),cookie(STAFF_CHALLENGE_COOKIE,'',0)]);return result;
  }
}
