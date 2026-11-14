function run_closed24(capacitances)
% Independent 24V -> 72V PI feasibility tests. No existing NN is reused.
if nargin<1,capacitances=[202e-6 220e-6];end
here=fileparts(mfilename('fullpath'));cfg=parameters24('SISO_VS_VO');
for cap=capacitances
 for delta=[0 .027]
  cfg.Co=cap;tag=sprintf('C%g_delay%gns',cap*1e6,delta/cfg.fsw*1e9);folder=fullfile(here,'results','closed72');if ~isfolder(folder),mkdir(folder);end
  file=fullfile(folder,[tag '.mat']);if isfile(file),fprintf('CLOSED24_CACHED %s\n',tag);continue;end
  [~,src]=fileparts(cfg.source);mdl=['TPC_' cfg.id '_OPEN'];if bdIsLoaded(src),close_system(src,0);end;if bdIsLoaded(mdl),close_system(mdl,0);end
  cfg.nominalDuty=.75;mdl=tpc_make_plant(cfg,144,'open');setup_cc24(mdl,cfg);
  mw=get_param(mdl,'ModelWorkspace');assignin(mw,'LOAD_SEQUENCE',[0 .5;.06 1;.08 .5;.09 .5]);
  duty=.75;L=cfg.L;C=cfg.Co;A=[-.1/L,-(1-duty)/L;(1-duty)/C,0];B=[(cfg.Vs+cfg.Vref)/L;-4/C];
  plant=c2d(ss(A,B,eye(2),zeros(2,1)),cfg.Ts,'zoh');
  opt=pidtuneOptions('PhaseMargin',65,'DesignFocus','disturbance-rejection');seed=pid(1,1,0,'Ts',cfg.Ts,'IFormula','ForwardEuler');
  [ci,ii]=pidtune(plant(1),seed,2*pi*2000,opt);outer=minreal(plant(2)*feedback(ci,plant(1)),1e-8);[cv,vi]=pidtune(outer,seed,2*pi*300,opt);
  p=struct('KpI',ci.Kp,'KiI',ci.Ki,'KpV',cv.Kp,'KiV',cv.Ki,'Ts',cfg.Ts,'reference',72,'dutyMax',.85,'currentRefMax',6,'innerPhaseMargin',ii.PhaseMargin,'outerPhaseMargin',vi.PhaseMargin,'assumedWindingResistance',.1,'dutyExtension',delta);
  old=[mdl '/TPC_Command_1'];ph=get_param(old,'PortHandles');line=get_param(ph.Outport(1),'Line');dst=get_param(line,'DstPortHandle');delete_line(line);delete_block(old);
  control=[mdl '/PI72'];add_block('simulink/User-Defined Functions/MATLAB Function',control);
  rt=sfroot;chart=rt.find('-isa','Stateflow.EMChart','Path',control);body=fileread(fullfile(here,'pi72_template.txt'));
  body=strrep(body,'@PARAMETERS@',sprintf('Ts=%.17g;kpI=%.17g;kiI=%.17g;kpV=%.17g;kiV=%.17g;delta=%.17g;',cfg.Ts,ci.Kp,ci.Ki,cv.Kp,cv.Ki,delta));chart.Script=body;
  add_block('simulink/Signal Routing/Mux',[mdl '/PI72_Features'],'Inputs','2');add_line(mdl,[cfg.currentSensor '/1'],'PI72_Features/1');add_line(mdl,[cfg.voltageSensor '/1'],'PI72_Features/2');
  add_block('simulink/Discrete/Zero-Order Hold',[mdl '/PI72_Sample'],'SampleTime',num2str(cfg.Ts,17));add_line(mdl,'PI72_Features/1','PI72_Sample/1');add_line(mdl,'PI72_Sample/1','PI72/1');
  add_block('simulink/Sources/Digital Clock',[mdl '/PI72_Time'],'SampleTime',num2str(cfg.Ts,17));add_line(mdl,'PI72_Time/1','PI72/2');ph=get_param(control,'PortHandles');for d=dst(:)',if get_param(d,'Line')>0,delete_line(get_param(d,'Line'));end;add_line(mdl,ph.Outport(1),d,'autorouting','on');end
  set_param([mdl '/TPC_FullTrace'],'SampleTime','1e-7');set_param(mdl,'StopTime','.09','MaxStep','1e-7','RelTol','1e-6');save_system(mdl);
  fprintf('CLOSED24_START %s\n',tag);tic;out=sim(mdl);elapsed=toc;z=out.get('TPC_trace');t=z.Time(:);a=squeeze(z.Data);if size(a,1)~=numel(t),a=a';end;assert(all(isfinite(a),'all'));
  g=floor((t+1e-12)/cfg.Ts);[ids,~,q]=unique(g);n=accumarray(q,1);ok=n>=99;tc=(ids(ok)+.5)*cfg.Ts;ac=zeros(sum(ok),size(a,2));for k=1:size(a,2),v=accumarray(q,a(:,k))./n;ac(:,k)=v(ok);end
  windows=[.055 .059;.075 .079;.085 .089];P=cell(3,1);
  for k=1:3
   w=t>=windows(k,1)&t<windows(k,2);i=a(w,1);tt=t(w);[~,~,bins]=unique(floor((tt+1e-12)/cfg.Ts));mn=accumarray(bins,i,[],@min);mx=accumarray(bins,i,[],@max);v=mean(a(w,2));
   P{k}=struct('window',windows(k,:),'meanVoltage',v,'relativeErrorPct',100*abs(v/72-1),'meanCurrent',mean(i),'rmsCurrent',sqrt(mean(i.^2)),'peakCurrent',max(i),'minCurrent',min(i),'meanCycleRipple',mean(mx-mn),'fractionCyclesAbove20mA',mean(mn>.02),'actualLoadCurrent',mean(a(w,3)));
  end
  E=cell(2,1);for k=1:2,te=cfg.events(k);w=tc>=te&tc<=te+.008;pre=tc>=te-.001&tc<te;idx=find(w);bad=idx(abs(ac(idx,2)-72)>.72);settle=0;if ~isempty(bad),settle=NaN;if bad(end)<idx(end),settle=(tc(bad(end)+1)-te)*1e6;end;end;E{k}=struct('time',te,'peakDepartureV',max(abs(ac(w,2)-mean(ac(pre,2)))),'settleWithin1PctUs',settle);end
  report=struct('case',tag,'Vs',24,'Vref',72,'L',L,'C',C,'plateaus',vertcat(P{:}),'events',vertcat(E{:}),'startupPeakCurrent',max(abs(a(t<.03,1))),'elapsedSeconds',elapsed,'controller',p);
  raw=t>=.0598&t<=.0605|t>=.0798&t<=.0805|t>=.0898;rawT=t(raw);rawA=a(raw,:);save(file,'tc','ac','rawT','rawA','report','cfg','p','-v7.3');fid=fopen(fullfile(folder,[tag '.json']),'w');fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
  save_system(mdl,fullfile(folder,['PI72_' tag '.slx']));close_system(['PI72_' tag],0);fprintf('CLOSED24_COMPLETE %s V=%g Imin=%g Imax=%g\n',tag,P{2}.meanVoltage,P{2}.minCurrent,P{2}.peakCurrent);
 end
end
end
