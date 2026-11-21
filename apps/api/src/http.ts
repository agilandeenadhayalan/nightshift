import { ArgumentsHost, Body, Catch, Controller, Delete, ExceptionFilter, Get, HttpCode, HttpException, Inject, Module,
  Param, Post, Put, Query, Req, Res, UseGuards, CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { Request, Response, raw } from 'express';
import { randomUUID } from 'node:crypto';
import { Auth, Actor, tokenHash } from './auth';
import { NightShiftService } from './service';
import { ApiError, requireThat } from './errors';
import { Config } from './config';
import { Database } from './db';
import { Presence } from './presence';
import { Server } from 'socket.io';
import { createPhoneAuthentication, PhoneAuthentication, PhoneAuthDependencies } from './identity/phone-auth';
import { Onboarding } from './identity/onboarding';
import { AccountLifecycle } from './account-lifecycle';
import { ListenerApplications, LocalReviewStorage } from './listener-applications';
import { DirectorySubscription } from './directory';
import { StaffAuthority } from './staff/authority';
import { StaffController } from './staff/http';
import { createStaffAuthority } from './staff/factory';
import { StaffReviewQueries } from './staff/review-queries';
import { StaffReviewController } from './staff/review-http';
import { StaffReviewDecisions } from './staff/review-decisions';
import { StaffReviewDecisionController } from './staff/review-decision-http';
import { createStaffReviewDecisions,loadApprovedReviewPolicy } from './staff/review-factory';

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
@Injectable()
class OnboardingSessionGuard implements CanActivate {
  constructor(@Inject(Auth) private readonly auth:Auth){}
  async canActivate(context:ExecutionContext){
    const req=context.switchToHttp().getRequest<AuthenticatedRequest>();
    const header=req.headers.authorization;
    req.actor=await this.auth.authenticate(header?.startsWith('Bearer ')?header.slice(7):undefined,true);return true;
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
    @Inject(PhoneAuthentication) private readonly phone:PhoneAuthentication,@Inject(AccountLifecycle) private readonly lifecycle:AccountLifecycle){}
  @Post('account-deletion/status') async deletionStatus(@Body() body:unknown,@Req() req:Request){
    requireThat(await this.service.presence.rateLimit(`deletion-receipt:${tokenHash(req.ip??'unknown')}`,30,60),429,'RATE_LIMITED','Wait before checking again.');
    return this.lifecycle.status(body);
  }
  @Post('auth/otp/request') requestOtp(@Body() body:unknown,@Req() req:Request){return this.phone.request(body,req.ip??'unknown',req.headers['idempotency-key']);}
  @Post('auth/otp/verify') verifyOtp(@Body() body:unknown,@Req() req:Request){return this.phone.verify(body,req.ip??'unknown');}
  @Post('auth/firebase/verify') verifyIdentity(@Body() body:unknown,@Req() req:Request){return this.phone.verifyIdentity(body,req.ip??'unknown');}
  @Post('auth/firebase/admissions') admitFirebasePhone(@Body() body:unknown,@Req() req:Request){return this.phone.admit(body,req.ip??'unknown',req.headers['idempotency-key']);}
  @Post('auth/exchange') async exchange(@Body() body:unknown,@Req() req:Request){
    const result=await this.auth.exchange(body,req.ip??'unknown');
    return {token:result.token,expiresAt:result.expiresAt,user:await this.service.user(result.userId),needsOnboarding:result.needsOnboarding,testOnly:true};
  }
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
@UseGuards(OnboardingSessionGuard)
class AccountController {
  constructor(@Inject(Auth) private readonly auth:Auth,@Inject(NightShiftService) private readonly service:NightShiftService,
    @Inject(Onboarding) private readonly onboarding:Onboarding,@Inject(AccountLifecycle) private readonly lifecycle:AccountLifecycle){}
  @Post('auth/logout') async logout(@Req() req:AuthenticatedRequest){await this.auth.logout(req.actor,c=>this.service.logoutCall(req.actor,c));return {signedOut:true};}
  @Get('me/onboarding') get(@Req() req:AuthenticatedRequest){return this.onboarding.get(req.actor);}
  @Put('me/onboarding') complete(@Req() req:AuthenticatedRequest,@Body() body:unknown){return this.onboarding.complete(req.actor,body);}
  @Get('me/consents') consents(@Req() req:AuthenticatedRequest){return this.lifecycle.consentHistory(req.actor);}
  @Get('me/deletion-notice') deletionNotice(){return this.lifecycle.deletionNotice();}
  @Post('me/deletion-requests') deletionRequest(@Req() req:AuthenticatedRequest,@Body() body:unknown){return this.lifecycle.requestDeletion(req.actor,body);}
}
@Controller('v1')
@UseGuards(SessionGuard)
class AppController {
  constructor(@Inject(Auth) private readonly auth:Auth,@Inject(NightShiftService) private readonly service:NightShiftService,
    @Inject(ListenerApplications) private readonly applications:ListenerApplications,@Inject(StaffReviewDecisions) private readonly decisions:StaffReviewDecisions){}
  @Get('me/listener-application/review') reviewStatus(@Req()req:AuthenticatedRequest,@Query()query:unknown){requireThat(!query||Object.keys(query).length===0,400,'INVALID_FIELD','No review query fields are accepted.');return this.decisions.ownerStatus(req.actor);}
  @Get('me/listener-application') application(@Req() req:AuthenticatedRequest){return this.applications.get(req.actor);}
  @Post('listener-applications') createApplication(@Req() req:AuthenticatedRequest,@Body() body:unknown){return this.applications.create(req.actor,body,req.headers['idempotency-key']);}
  @Put('listener-applications/:id') updateApplication(@Req() req:AuthenticatedRequest,@Param('id') id:string,@Body() body:unknown){return this.applications.update(req.actor,id,body);}
  @Post('listener-applications/:id/uploads') issueReviewUpload(@Req() req:AuthenticatedRequest,@Param('id') id:string,@Body() body:unknown){return this.applications.issueUpload(req.actor,id,body,req.headers['idempotency-key']);}
  @Put('listener-applications/:id/uploads/:uploadId') uploadSample(@Req() req:AuthenticatedRequest,@Param('id') id:string,@Param('uploadId') uploadId:string,@Body() body:Buffer){return this.applications.upload(req.actor,id,uploadId,req.headers['x-upload-token'],req.headers['content-type'],body);}
  @Get('listener-applications/:id/uploads/:uploadId') async readSample(@Req() req:AuthenticatedRequest,@Param('id') id:string,@Param('uploadId') uploadId:string,@Res() res:Response){
    const sample=await this.applications.readUpload(req.actor,id,uploadId);
    res.setHeader('Content-Type',sample.contentType);res.setHeader('Content-Disposition','attachment; filename="review-sample.wav"');res.send(sample.bytes);
  }
  @Post('listener-applications/:id/submit') submitApplication(@Req() req:AuthenticatedRequest,@Param('id') id:string){return this.applications.submit(req.actor,id,req.headers['idempotency-key']);}
  @Post('listener-applications/:id/withdraw') withdrawApplication(@Req() req:AuthenticatedRequest,@Param('id') id:string){return this.applications.withdraw(req.actor,id,req.headers['idempotency-key']);}
  @Get('me') me(@Req() req:AuthenticatedRequest){return this.service.user(req.actor.id);}
  @Get('snapshot') snapshot(@Req() req:AuthenticatedRequest,@Query('language') language?:string){return this.service.snapshot(req.actor,language);}
  @Put('me/mode') mode(@Req() req:AuthenticatedRequest,@Body() body:unknown){return this.service.mode(req.actor,body);}
  @Put('me/availability') availability(@Req() req:AuthenticatedRequest,@Body() body:unknown){return this.service.availability(req.actor,body);}
  @Put('me/languages') languages(@Req() req:AuthenticatedRequest,@Body() body:unknown){return this.service.languages(req.actor,body);}
  @Post('presence/heartbeat') heartbeat(@Req() req:AuthenticatedRequest){return this.service.heartbeat(req.actor);}
  @Get('listeners') listeners(@Req() req:AuthenticatedRequest,@Query('language') language?:string,@Query('cursor') cursor?:string,@Query('availableOnly') availableOnly?:string){return this.directoryPage(req,false,language,cursor,availableOnly);}
  @Get('favorites') favorites(@Req() req:AuthenticatedRequest,@Query('language') language?:string,@Query('cursor') cursor?:string,@Query('availableOnly') availableOnly?:string){return this.directoryPage(req,true,language,cursor,availableOnly);}
  private directoryPage(req:AuthenticatedRequest,favorites:boolean,language?:string,cursor?:string,availableOnly?:string){
    requireThat(availableOnly===undefined||availableOnly==='true'||availableOnly==='false',400,'INVALID_FIELD','availableOnly must be true or false');
    return this.service.directory.page(req.actor,{language,cursor,availableOnly:availableOnly==='true'},favorites);
  }
  @Post('listeners/status') listenerStatuses(@Req() req:AuthenticatedRequest,@Body() body:unknown){return this.service.directory.statuses(req.actor,body);}
  @Get('calls') history(@Req() req:AuthenticatedRequest,@Query('cursor') cursor?:string){return this.service.history(req.actor.id,cursor);}
  @Get('calls/:id') call(@Req() req:AuthenticatedRequest,@Param('id') id:string){return this.service.call(req.actor.id,id);}
  @Post('calls') create(@Req() req:AuthenticatedRequest,@Body() body:unknown){return this.service.createCall(req.actor,body,req.headers['idempotency-key']);}
  @Post('matches') @HttpCode(200) createMatch(@Req()req:AuthenticatedRequest,@Body()body:unknown,@Query()query:unknown){this.matchQuery(query);return this.service.matching.start(req.actor,body,req.headers['idempotency-key']);}
  @Get('me/match') currentMatch(@Req()req:AuthenticatedRequest,@Query()query:unknown){this.matchQuery(query);return this.service.matching.current(req.actor);}
  @Get('matches/:id') match(@Req()req:AuthenticatedRequest,@Param('id')id:string,@Query()query:unknown){this.matchQuery(query);return this.service.matching.get(req.actor,id);}
  @Post('matches/:id/cancel') @HttpCode(200) cancelMatch(@Req()req:AuthenticatedRequest,@Param('id')id:string,@Body()body:unknown,@Query()query:unknown){this.matchQuery(query);return this.service.matching.cancel(req.actor,id,body,req.headers['idempotency-key']);}
  private matchQuery(query:unknown){requireThat(!query||Object.keys(query).length===0,400,'INVALID_FIELD','No matching query fields are accepted.');}
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
  requireThat(!config.staffReviewPolicyFile||config.staffAuth,503,'REVIEW_POLICY_UNAVAILABLE','Approved review policy requires configured staff authority.');
  const approvedReviewPolicy=await loadApprovedReviewPolicy(config.staffReviewPolicyFile);
  const db=new Database(config.databaseUrl),presence=new Presence(config.redisUrl);
  await presence.connect();
  let phone:PhoneAuthentication;
  try{phone=await createPhoneAuthentication(db,presence,config,clock,identityTestAdapters);}
  catch(error){await presence.close();await db.close();throw error;}
  const auth=new Auth(db,presence,config,phone,clock),service=new NightShiftService(db,presence,config,clock);
  const onboarding=new Onboarding(db,clock,async actor=>{await service.logoutCall(actor);await service.withdrawPresence(actor.id);});
  const reviewStorage=config.privateReviewDirectory?new LocalReviewStorage(config.privateReviewDirectory):undefined;
  const applications=new ListenerApplications(db,{storage:reviewStorage,capabilityKey:config.devAccessKey},clock);
  const lifecycle=new AccountLifecycle(db,clock,userId=>service.withdrawPresence(userId),userId=>applications.erasePrivateMaterials(userId));
  let staffRuntime:ReturnType<typeof createStaffAuthority>;
  try{staffRuntime=createStaffAuthority(db,auth,config,clock);}catch(error){await phone.close();await presence.close();await db.close();throw error;}
  const staff=staffRuntime.authority;
  // The fallback key cannot enable a disabled staff authority; it only keeps
  // the read service constructible in the existing default-off bootstrap.
  const reviews=new StaffReviewQueries(db,staff,{storage:reviewStorage,cursorKey:config.staffAuth?.digestKey??tokenHash(config.devAccessKey),decisionsEnabled:()=>decisions.policy().enabled},clock);
  const decisions=createStaffReviewDecisions(db,staff,reviews,approvedReviewPolicy,clock);
  @Module({controllers:[PublicController,AccountController,AppController,StaffController,StaffReviewController,StaffReviewDecisionController],providers:[SessionGuard,OnboardingSessionGuard,{provide:Auth,useValue:auth},{provide:NightShiftService,useValue:service},{provide:PhoneAuthentication,useValue:phone},{provide:Onboarding,useValue:onboarding},{provide:AccountLifecycle,useValue:lifecycle},{provide:ListenerApplications,useValue:applications},{provide:StaffAuthority,useValue:staff},{provide:StaffReviewQueries,useValue:reviews},{provide:StaffReviewDecisions,useValue:decisions}]})
  class AppModule{}
  const app=await NestFactory.create(AppModule,{logger:['error','warn'],bodyParser:true});
  app.use((req:AuthenticatedRequest,res:Response,next:()=>void)=>{
    req.requestId=randomUUID();res.setHeader('X-Request-Id',req.requestId);res.setHeader('Cache-Control','no-store');
    res.setHeader('X-Content-Type-Options','nosniff');next();
  });
  const parseReviewWave=raw({type:'audio/wav',limit:2097152,inflate:false});
  app.use('/v1/listener-applications',(req:AuthenticatedRequest,res:Response,next:()=>void)=>{
    parseReviewWave(req,res,(error?:{type?:string})=>{
      if(!error){next();return;}
      const oversized=error.type==='entity.too.large';
      res.status(oversized?413:400).json({error:{code:oversized?'UPLOAD_TOO_LARGE':'INVALID_UPLOAD',message:oversized?'Choose a WAV sample of at most 2 MiB.':'The sample upload could not be read.'},requestId:req.requestId});
    });
  });
  app.useGlobalFilters(new ErrorFilter());
  // The native app does not need browser CORS. No wildcard browser origin or token-bearing URL.
  const io=new Server(app.getHttpServer(),{transports:['websocket'],maxHttpBufferSize:16384});
  io.use(async(socket,next)=>{
    try{socket.data.actor=await auth.authenticate(socket.handshake.auth.token);socket.data.token=socket.handshake.auth.token;next();}
    catch{next(new Error('UNAUTHENTICATED'));}
  });
  io.on('connection',socket=>{
    socket.join(`user:${(socket.data.actor as Actor).id}`);
    socket.data.directoryRevision=0;socket.data.directoryPending=false;
    type SubscriptionRequest={raw:unknown;revision:number;reply:(value:unknown)=>void};
    let queued:SubscriptionRequest|undefined;
    const validateNext=()=>{
      if(socket.data.directoryPending||!queued||!socket.connected)return;
      const {raw,revision,reply}=queued;queued=undefined;
      socket.data.directoryPending=true;
      void(async()=>{
        try{
          const actor=await auth.authenticate(socket.data.token);
          const subscription=await service.directory.subscribe(actor,raw);
          if(!socket.connected)return;
          if(revision!==socket.data.directoryRevision){reply({ok:false,code:'DIRECTORY_SUBSCRIPTION_SUPERSEDED'});return;}
          socket.data.directory=subscription;socket.data.directoryFingerprint=undefined;socket.data.directorySentAt=0;
          reply({ok:true,viewEpoch:subscription?.viewEpoch??null});
        }catch(error){if(socket.connected)reply({ok:false,code:revision!==socket.data.directoryRevision?'DIRECTORY_SUBSCRIPTION_SUPERSEDED':error instanceof ApiError?error.code:'SERVICE_UNAVAILABLE'});}
        finally{socket.data.directoryPending=false;validateNext();}
      })();
    };
    socket.on('directory.subscribe',(raw:unknown,ack?:unknown)=>{
      const reply=(value:unknown)=>{if(typeof ack==='function')ack(value);};
      // Invalidate the old slice immediately. Coalesce rapid scroll/filter
      // changes into one latest request behind at most one active validation.
      const revision=++socket.data.directoryRevision;socket.data.directory=undefined;
      queued?.reply({ok:false,code:'DIRECTORY_SUBSCRIPTION_SUPERSEDED'});
      queued={raw,revision,reply};validateNext();
    });
    socket.on('disconnect',()=>{++socket.data.directoryRevision;socket.data.directory=undefined;queued=undefined;});
  });
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
  // Directory reads cannot hold up call recovery or durable call delivery.
  // Four workers cap the extra DB/provider concurrency; passes never overlap.
  let directoryRunning=false;
  const directoryTimer=setInterval(()=>void(async()=>{
    if(directoryRunning)return;directoryRunning=true;
    try{
      const pending=[...io.sockets.sockets.values()].filter(socket=>socket.data.directory);let next=0;
      await Promise.all(Array.from({length:Math.min(4,pending.length)},async()=>{
        while(next<pending.length){
          const socket=pending[next++]!;
          const subscription=socket.data.directory as DirectorySubscription|undefined;
          if(!socket.connected||!subscription)continue;
          const revision=socket.data.directoryRevision;
          try{
            const actor=await auth.authenticate(socket.data.token);
            const update=await service.directory.updates(actor,subscription);
            if(!socket.connected||revision!==socket.data.directoryRevision)continue;
            const fingerprint=JSON.stringify({items:update.items,removedIds:update.removedIds});
            if(fingerprint!==socket.data.directoryFingerprint||clock()-socket.data.directorySentAt>=15000){
              socket.emit('directory.updated',update);socket.data.directoryFingerprint=fingerprint;socket.data.directorySentAt=clock();
            }
          }catch(error){
            if(socket.connected&&revision===socket.data.directoryRevision){socket.data.directory=undefined;
              socket.emit('directory.invalidated',{viewEpoch:subscription.viewEpoch,code:error instanceof ApiError?error.code:'SERVICE_UNAVAILABLE'});}
          }
        }
      }));
    }finally{directoryRunning=false;}
  })(),1000);directoryTimer.unref();
  // Matching has its own bounded pass so candidate liveness I/O cannot delay
  // existing media recovery or call-event delivery.
  let matchingRunning=false;
  const matchingTimer=setInterval(()=>void(async()=>{
    if(matchingRunning)return;matchingRunning=true;
    try{await service.matching.processPending();}catch{/* Durable work retries without logging private records. */}
    finally{matchingRunning=false;}
  })(),1000);matchingTimer.unref();
  // Privacy recovery is bounded and independent of the call/media control loop.
  let privacyRunning=false;
  const privacyTimer=setInterval(()=>void(async()=>{
    if(privacyRunning)return;privacyRunning=true;
    try{
      // Each recovery pass gets a chance even when the other storage boundary fails.
      await Promise.allSettled([lifecycle.processPending(),applications.sweepExpiredUploads(),service.directory.cleanupExpired(),staff.cleanupAccessRequests(),decisions.processPending()]);
    }catch{/* Retry durable work on the next tick; never log private records. */}
    finally{privacyRunning=false;}
  })(),30000);privacyTimer.unref();
  await app.init();
  return {app,db,presence,auth,service,phone,lifecycle,applications,decisions,async close(){clearInterval(timer);clearInterval(directoryTimer);clearInterval(matchingTimer);clearInterval(privacyTimer);await io.close();await app.close();await staffRuntime.close();await phone.close();await presence.close();await db.close();}};
}
