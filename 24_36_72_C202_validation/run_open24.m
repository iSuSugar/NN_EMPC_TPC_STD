function run_open24(ids)
% Replicate the measured low-voltage operating conditions without altering the formal baseline.
if nargin<1,ids={'SISO_VS_VO','SISO_VB_VO','SISO_VS_VB','SIDO','DISO'};end
here=fileparts(mfilename('fullpath'));
for j=1:numel(ids)
 for variant={'command','vgs_proxy'}
  cfg=parameters24(ids{j});cfg.variant=variant{1};
  switch cfg.id
   case 'SISO_VS_VO',cmd=.725;measured=.7522;
   case 'SISO_VB_VO',cmd=.410;measured=.437;
   case 'SISO_VS_VB',cmd=.350;measured=.350;
   case 'SIDO',cmd=.691;measured=.716;cfg.fixedDutyS1=.750;if strcmp(cfg.variant,'vgs_proxy'),cfg.fixedDutyS1=.777;end
   case 'DISO',cmd=[.361;.204];measured=[.388;.231];
  end
  cfg.nominalDuty=cmd;if strcmp(cfg.variant,'vgs_proxy'),cfg.nominalDuty=measured;end
  folder=fullfile(here,'results',cfg.id);if ~isfolder(folder),mkdir(folder);end
  file=fullfile(folder,['open_' cfg.variant '.mat']);if isfile(file),fprintf('OPEN24_CACHED %s %s\n',cfg.id,cfg.variant);continue;end
  [~,src]=fileparts(cfg.source);mdl=['TPC_' cfg.id '_OPEN'];if bdIsLoaded(src),close_system(src,0);end;if bdIsLoaded(mdl),close_system(mdl,0);end
  mdl=tpc_make_plant(cfg,144,'open');
  setup_cc24(mdl,cfg);
  for ch=1:cfg.nu
   block=[mdl '/TPC_Command_' num2str(ch)];replaceConstant(mdl,block,[0 0;.02 cfg.nominalDuty(ch);.09 cfg.nominalDuty(ch)],['CMD' num2str(ch)]);
  end
  if strcmp(cfg.id,'SIDO'),replaceConstant(mdl,[mdl '/TPC_FixedS1'],[0 0;.02 cfg.fixedDutyS1;.09 cfg.fixedDutyS1],'FIXED');end
  set_param([mdl '/TPC_FullTrace'],'SampleTime','1e-7');set_param(mdl,'MaxStep','1e-7','RelTol','1e-6','StopTime','.09');save_system(mdl);
  fprintf('OPEN24_START %s %s\n',cfg.id,cfg.variant);tic;out=sim(mdl);elapsed=toc;z=out.get('TPC_trace');t=z.Time(:);a=squeeze(z.Data);if size(a,1)~=numel(t),a=a';end;assert(all(isfinite(a),'all'));
  [tc,ac]=cycle(t,a,cfg.Ts);report=metrics(t,a,cfg);report.elapsedSeconds=elapsed;report.variant=cfg.variant;
  assert(max(abs([report.plateaus.actualLoadCurrent]-[.5 1 .5]))<.02,'Measured load current does not match the declared CC sink.');
  raw=t>=.0598&t<=.0602|t>=.0798&t<=.0802|t>=.0898;rawT=t(raw);rawA=a(raw,:);
  save(file,'tc','ac','rawT','rawA','report','cfg','-v7.3');fid=fopen(fullfile(folder,['open_' cfg.variant '.json']),'w');fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
  dest=fullfile(folder,['OPEN_' cfg.id '_' cfg.variant '.slx']);[~,target]=fileparts(dest);if bdIsLoaded(target),close_system(target,0);end;save_system(mdl,dest);close_system(target,0);
  fprintf('OPEN24_COMPLETE %s %s Vo=%.4f Imean=%.4f Irms=%.4f Ipp=%.4f min=%.4f\n',cfg.id,cfg.variant,report.plateaus(2).meanVoltage,report.plateaus(2).meanCurrent,report.plateaus(2).rmsCurrent,report.plateaus(2).meanCycleRipple,report.plateaus(2).minCurrent);
 end
end
end
function replaceConstant(mdl,block,sequence,name)
ph=get_param(block,'PortHandles');lh=get_param(ph.Outport(1),'Line');dst=get_param(lh,'DstPortHandle');delete_line(lh);delete_block(block);
add_block('simulink/Sources/From Workspace',block,'VariableName',name,'Interpolate','on','OutputAfterFinalValue','Holding final value');mw=get_param(mdl,'ModelWorkspace');assignin(mw,name,sequence);p=get_param(block,'PortHandles');for d=dst(:)',add_line(mdl,p.Outport(1),d,'autorouting','on');end
end
function [tc,ac]=cycle(t,a,Ts)
g=floor((t+1e-12)/Ts);[ids,~,q]=unique(g);n=accumarray(q,1);ok=n>=99;tc=(ids(ok)+.5)*Ts;ac=zeros(sum(ok),size(a,2));for k=1:size(a,2),v=accumarray(q,a(:,k))./n;ac(:,k)=v(ok);end
end
function report=metrics(t,a,cfg)
windows=[.055 .059;.075 .079;.085 .089];P=cell(3,1);
for k=1:3
 w=t>=windows(k,1)&t<windows(k,2);i=a(w,1);tt=t(w);g=floor((tt+1e-12)/cfg.Ts);[~,~,q]=unique(g);mins=accumarray(q,i,[],@min);maxs=accumarray(q,i,[],@max);
 P{k}=struct('window',windows(k,:),'meanVoltage',mean(a(w,2)),'meanCurrent',mean(i),'rmsCurrent',sqrt(mean(i.^2)),'peakCurrent',max(i),'minCurrent',min(i),'meanCycleRipple',mean(maxs-mins),'fractionCyclesAbove20mA',mean(mins>.02),'fractionSamplesNearZero',mean(abs(i)<.02),'actualLoadCurrent',mean(a(w,3)));
end
report=struct('id',cfg.id,'Vs',cfg.Vs,'Vb',cfg.Vb,'L',cfg.L,'C',cfg.Co,'duty',cfg.nominalDuty,'plateaus',vertcat(P{:}),'startupPeak',max(abs(a(t<.03,1))),'note','Vgs proxy is a sensitivity case, not a validated effective MOS on-time. CC compliance model uses 5V; real electronic load dynamics and driver ringing are not modeled.');
end
