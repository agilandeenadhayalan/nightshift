import { ArgumentsHost, Body, Catch, Controller, Delete, ExceptionFilter, Get, HttpException, Inject, Module,
  Param, Post, Put, Query, Req, UseGuards, CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { Request, Response } from 'express';
import { randomUUID } from 'node:crypto';
import { Auth, Actor } from './auth';
import { NightShiftService } from './service';
import { ApiError } from './errors';
import { Config } from './config';
import { Database } from './db';
import { Presence } from './presence';
import { Server } from 'socket.io';
import { createPhoneAuthentication, PhoneAuthentication, PhoneAuthDependencies } from './identity/phone-auth';

type AuthenticatedRequest=Request & {actor:Actor;requestId:string};
@Injectable()
class SessionGuard implements CanActivate {
  constructor(@Inject(Auth) private readonly auth:Auth){}
  async canActivate(context:ExecutionContext){
    const req=context.switchToHttp().getRequest<AuthenticatedRequest>();
    const header=req.headers.authorization;
    req.actor=await this.auth.authenticate(header?.startsWith('Bearer ')?header.slice(7):undefined);return true;
  }
}
@Catch()
class ErrorFilter implements ExceptionFilter {
  catch(exception:unknown,host:ArgumentsHost){
    const req=host.switchToHttp().getRequest<AuthenticatedRequest>(),res=host.switchToHttp().getResponse<Response>();
    const known=exception instanceof ApiError;
    const status=known?exception.status:exception instanceof HttpException?exception.getStatus():503;
    const retry=known && 'retryAfterSeconds' in exception && typeof exception.retryAfterSeconds==='number'
      && Number.isSafeInteger(exception.retryAfterSeconds) && exception.retryAfterSeconds>0 ? exception.retryAfterSeconds : undefined;
    if(retry!==undefined)res.setHeader('Retry-After',String(retry));
    res.status(status).json({error:{code:known?exception.code:status===404?'NOT_FOUND':'SERVICE_UNAVAILABLE',
      message:known?exception.message:status===404?'Endpoint not found':'Service is temporarily unavailable',
      ...(retry===undefined?{}:{retryAfterSeconds:retry})},requestId:req.requestId??randomUUID()});
  }
}
@Controller('v1')
class PublicController {
  constructor(@Inject(Auth) private readonly auth:Auth,@Inject(NightShiftService) private readonly service:NightShiftService,
    @Inject(PhoneAuthentication) private readonly phone:PhoneAuthentication){}
  @Post('auth/otp/request') requestOtp(@Body() body:unknown,@Req() req:Request){return this.phone.request(body,req.ip??'unknown',req.headers['idempotency-key']);}
  @Post('auth/otp/verify') verifyOtp(@Body() body:unknown,@Req() req:Request){return this.phone.verify(body,req.ip??'unknown');}
  @Post('auth/firebase/verify') verifyIdentity(@Body() body:unknown,@Req() req:Request){return this.phone.verifyIdentity(body,req.ip??'unknown');}
  @Post('auth/dev') async login(@Body() body:unknown,@Req() req:Request){
    const result=await this.auth.login(body,req.ip??'unknown');
    return {token:result.token,expiresAt:result.expiresAt,user:await this.service.user(result.userId),testOnly:true};
  }
  @Get('health') async health(){
    await this.service.db.pool.query('SELECT 1');await this.service.presence.healthy();
    return {status:'ok',service:'nightshift-api',testOnly:true};
  }
}
@Controller('v1')
@UseGuards(SessionGuard)
class AppController {
  constructor(@Inject(Auth) private readonly auth:Auth,@Inject(NightShiftService) private readonly service:NightShiftService){}
  @Post('auth/logout') async logout(@Req() req:AuthenticatedRequest){await this.service.logoutCall(req.actor);await this.auth.logout(req.actor);return {signedOut:true};}
  @Get('me') me(@Req() req:AuthenticatedRequest){return this.service.user(req.actor.id);}
  @Get('snapshot') snapshot(@Req() req:AuthenticatedRequest,@Query('language') language?:string){return this.service.snapshot(req.actor,language);}
  @Put('me/mode') mode(@Req() req:AuthenticatedRequest,@Body() body:unknown){return this.service.mode(req.actor,body);}
  @Put('me/availability') availability(@Req() req:AuthenticatedRequest,@Body() body:unknown){return this.service.availability(req.actor,body);}
  @Put('me/languages') languages(@Req() req:AuthenticatedRequest,@Body() body:unknown){return this.service.languages(req.actor,body);}
  @Post('presence/heartbeat') heartbeat(@Req() req:AuthenticatedRequest){return this.service.heartbeat(req.actor);}
  @Get('listeners') listeners(@Req() req:AuthenticatedRequest,@Query('language') language?:string,@Query('cursor') cursor?:string){return this.service.listeners(req.actor.id,language,cursor);}
  @Get('calls') history(@Req() req:AuthenticatedRequest,@Query('cursor') cursor?:string){return this.service.history(req.actor.id,cursor);}
  @Get('calls/:id') call(@Req() req:AuthenticatedRequest,@Param('id') id:string){return this.service.call(req.actor.id,id);}
  @Post('calls') create(@Req() req:AuthenticatedRequest,@Body() body:unknown){return this.service.createCall(req.actor,body,req.headers['idempotency-key']);}
  @Post('calls/:id/media') media(@Req() req:AuthenticatedRequest,@Param('id') id:string,@Body() body:unknown){return this.service.media(req.actor,id,body);}
  @Post('calls/:id/rtc-token') rtcToken(@Req() req:AuthenticatedRequest,@Param('id') id:string){return this.service.rtcToken(req.actor,id);}
  @Get('rtc/config') rtcConfig(){return this.service.rtcConfig();}
  @Post('calls/:id/:action') action(@Req() req:AuthenticatedRequest,@Param('id') id:string,@Param('action') action:string,@Body() body:unknown){return this.service.action(req.actor,id,action,body,req.headers['idempotency-key']);}
  @Get('rates') rates(){return this.service.rates();}
  @Get('wallet') wallet(@Req() req:AuthenticatedRequest){return this.service.wallet(req.actor.id);}
  @Get('me/earnings') earnings(@Req() req:AuthenticatedRequest){return this.service.earnings(req.actor);}
  @Put('blocks/:id') block(@Req() req:AuthenticatedRequest,@Param('id') id:string){return this.service.block(req.actor,id);}
  @Put('favorites/:id') favorite(@Req() req:AuthenticatedRequest,@Param('id') id:string){return this.service.favorite(req.actor,id,true);}
  @Delete('favorites/:id') unfavorite(@Req() req:AuthenticatedRequest,@Param('id') id:string){return this.service.favorite(req.actor,id,false);}
  @Post('reports') report(@Req() req:AuthenticatedRequest,@Body() body:unknown){return this.service.report(req.actor,body,req.headers['idempotency-key']);}
  @Get('events') events(@Req() req:AuthenticatedRequest,@Query('cursor') cursor?:string){return this.service.events(req.actor,cursor);}
}

export async function createApplication(config:Config,clock:()=>number=Date.now,identityTestAdapters?:PhoneAuthDependencies){
  const db=new Database(config.databaseUrl),presence=new Presence(config.redisUrl);
  await presence.connect();
  let phone:PhoneAuthentication;
  try{phone=await createPhoneAuthentication(db,presence,config,clock,identityTestAdapters);}
  catch(error){await presence.close();await db.close();throw error;}
  const auth=new Auth(db,presence,config),service=new NightShiftService(db,presence,config,clock);
  @Module({controllers:[PublicController,AppController],providers:[SessionGuard,{provide:Auth,useValue:auth},{provide:NightShiftService,useValue:service},{provide:PhoneAuthentication,useValue:phone}]})
  class AppModule{}
  const app=await NestFactory.create(AppModule,{logger:['error','warn'],bodyParser:true});
  app.use((req:AuthenticatedRequest,res:Response,next:()=>void)=>{
    req.requestId=randomUUID();res.setHeader('X-Request-Id',req.requestId);res.setHeader('Cache-Control','no-store');
    res.setHeader('X-Content-Type-Options','nosniff');next();
  });
  app.useGlobalFilters(new ErrorFilter());
  // The native app does not need browser CORS. No wildcard browser origin or token-bearing URL.
  const io=new Server(app.getHttpServer(),{transports:['websocket'],maxHttpBufferSize:16384});
  io.use(async(socket,next)=>{
    try{socket.data.actor=await auth.authenticate(socket.handshake.auth.token);socket.data.token=socket.handshake.auth.token;next();}
    catch{next(new Error('UNAUTHENTICATED'));}
  });
  io.on('connection',socket=>{socket.join(`user:${(socket.data.actor as Actor).id}`);});
  let running=false;
  const timer=setInterval(()=>void(async()=>{
    if(running)return;running=true;
    try{
      await service.recover();
      for(const socket of io.sockets.sockets.values()){
        try{await auth.authenticate(socket.data.token);}catch{socket.disconnect(true);}
      }
      await db.tx(async c=>{
        const {rows}=await c.query(`SELECT o.id,o.recipient_id,e.kind,e.payload,e.id event_id,e.version,e.created_at
          FROM outbox_events o JOIN call_events e ON e.id=o.event_id WHERE o.delivered_at IS NULL
          ORDER BY o.created_at LIMIT 100 FOR UPDATE OF o SKIP LOCKED`);
        for(const row of rows){
          io.to(`user:${row.recipient_id}`).emit(row.kind,{...row.payload,eventId:row.event_id,timestamp:row.created_at});
          await c.query('UPDATE outbox_events SET delivered_at=now() WHERE id=$1',[row.id]);
        }
      });
    }catch{
      // An unavailable DB must not keep client media appearing authorized.
      io.emit('service.unavailable',{code:'SERVICE_UNAVAILABLE'});
    }finally{running=false;}
  })(),1000);timer.unref();
  await app.init();
  return {app,db,presence,auth,service,phone,async close(){clearInterval(timer);await io.close();await app.close();await phone.close();await presence.close();await db.close();}};
}
