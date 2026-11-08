function mdl=tpc_make_plant(cfg,Rload,kind,netData)
% Copy the original electrical model; replace only controller/sampling scaffolding.
if nargin<4,netData=[];end
outDir=fullfile(cfg.caseDir,'circuit');if ~isfolder(outDir),mkdir(outDir);end
mdl=['TPC_' cfg.id '_' upper(kind)];destination=fullfile(outDir,[mdl '.slx']);
[~,src]=fileparts(cfg.source);assert(~bdIsLoaded(src)&&~bdIsLoaded(mdl),'Close same-name models first.');
load_system(cfg.source);save_system(src,destination);close_system(src,0);load_system(destination);
set_param(mdl,'ReturnWorkspaceOutputs','on','SignalLogging','off','Solver','ode23tb','RelTol','1e-6','MaxStep','1e-7');
if strcmp(kind,'open'),set_param(mdl,'StopTime','0.01');if isfield(cfg,'openMaxStep'),set_param(mdl,'MaxStep',num2str(cfg.openMaxStep,17));end;else,set_param(mdl,'StopTime',num2str(max([cfg.events(:);.02])+.01,17));end
% Full-load Rload; the second equal branch creates half/full/half loading.
physicalR=Rload;if strcmp(kind,'closed'),physicalR=2*Rload;end
B=find_system(mdl,'SearchDepth',1,'Type','Block');
for k=1:numel(B)
 name=get_param(B{k},'Name');
 if strcmp(name,'DC Voltage Source1')
  set_param(B{k},'Amplitude',num2str(cfg.Vb,17));
 elseif strcmp(name,'DC Voltage Source')
  supply=cfg.Vs;if startsWith(cfg.id,'SISO_VB_VO'),supply=cfg.Vb;end;set_param(B{k},'Amplitude',num2str(supply,17));
 elseif contains(name,'PWM Generator')
  set_param(B{k},'Fsw',num2str(cfg.fsw,17),'Ts','0');
 elseif contains(name,'Series RLC Branch')
  try,rt=get_param(B{k},'BranchType');rr=str2double(get_param(B{k},'Resistance'));catch,continue;end
  target=strcmp(rt,'R')&&((strcmp(cfg.id,'SISO_VS_VB')&&any(strcmp(name,{'Series RLC Branch1','Series RLC Branch6'})))||(~strcmp(cfg.id,'SISO_VS_VB')&&rr>=100));
  if target,set_param(B{k},'Resistance',num2str(physicalR,17));end
  if strcmp(rt,'L')&&isfield(cfg,'L'),set_param(B{k},'Inductance',num2str(cfg.L,17));end
  if strcmp(rt,'C')&&isfield(cfg,'Co'),set_param(B{k},'Capacitance',num2str(cfg.Co,17));end
 elseif strcmp(get_param(B{k},'BlockType'),'Step')&&strcmp(kind,'open')
  set_param(B{k},'Before','0','After','0');
 end
end
% Parameterized fixed S1 duty in SIDO; the other duty remains an independent controller output.
if isfield(cfg,'fixedDutyS1')
 fixed=[mdl '/' cfg.fixedPwm];ph=get_param(fixed,'PortHandles');lh=get_param(ph.Inport(1),'Line');if lh~=-1,delete_line(lh);end
 add_block('simulink/Sources/Constant',[mdl '/TPC_FixedS1'],'Value',num2str(cfg.fixedDutyS1,17),'Position',[1750 40 1800 70]);add_line(mdl,'TPC_FixedS1/1',[cfg.fixedPwm '/1'],'autorouting','on');
end
% Independent duty command port for every active PWM channel.
for k=1:cfg.nu
 pwm=[mdl '/' cfg.activePwm{k}];ph=get_param(pwm,'PortHandles');lh=get_param(ph.Inport(1),'Line');if lh~=-1,delete_line(lh);end
 nm=sprintf('TPC_Command_%d',k);add_block('simulink/Sources/Constant',[mdl '/' nm],'Value',num2str(cfg.nominalDuty(k),17),'Position',[1800 100+60*k 1850 130+60*k]);
 add_line(mdl,[nm '/1'],[cfg.activePwm{k} '/1'],'autorouting','on');
end
% Four physical features, including actual instantaneous load current.
currentName='Current Measurement1';if strcmp(cfg.id,'SISO_VS_VB'),currentName='Current Measurement7';end
features={cfg.currentSensor,cfg.voltageSensor,currentName};
if strcmp(kind,'closed')
 add_block('simulink/Sources/Constant',[mdl '/TPC_Reference'],'Value',num2str(cfg.Vref,17),'Position',[1800 400 1850 430]);
 add_block('simulink/Signal Routing/Mux',[mdl '/TPC_Features'],'Inputs','4','Position',[1900 300 1910 450]);
 for k=1:3,add_line(mdl,[features{k} '/1'],sprintf('TPC_Features/%d',k),'autorouting','on');end
 add_line(mdl,'TPC_Reference/1','TPC_Features/4','autorouting','on');
 if isfield(cfg,'feedbackTiming')&&strcmp(cfg.feedbackTiming,'sample_hold')
  add_block('simulink/Discrete/Zero-Order Hold',[mdl '/TPC_FeedbackDelay'],'SampleTime',num2str(cfg.Ts,17),'Position',[1950 350 2000 390]);
 else
  add_block('simulink/Discrete/Unit Delay',[mdl '/TPC_FeedbackDelay'],'SampleTime',num2str(cfg.Ts,17),'InitialCondition',['[0;0;0;' num2str(cfg.Vref,17) ']'],'Position',[1950 350 2000 390]);
 end
 add_line(mdl,'TPC_Features/1','TPC_FeedbackDelay/1','autorouting','on');
 if iscell(netData)
  % Legacy MATLAB networks: a separate scalar output for each duty.
  for k=1:cfg.nu
   gensim(netData{k},cfg.Ts);g=bdroot;subs=find_system(g,'SearchDepth',1,'BlockType','SubSystem');assert(numel(subs)==1);
   name=sprintf('TPC_NN_%d',k);add_block(subs{1},[mdl '/' name],'Position',[2050 300+100*k 2200 370+100*k]);close_system(g,0);add_line(mdl,'TPC_FeedbackDelay/1',[name '/1'],'autorouting','on');
   replaceDuty(k,[name '/1']);
  end
 else
  tpc_add_relu_block(mdl,'TPC_NN',netData);add_line(mdl,'TPC_FeedbackDelay/1','TPC_NN/1','autorouting','on');
  if cfg.nu>1
   add_block('simulink/Signal Routing/Demux',[mdl '/TPC_Duties'],'Outputs',num2str(cfg.nu),'Position',[2250 300 2260 420]);add_line(mdl,'TPC_NN/1','TPC_Duties/1','autorouting','on');
   for k=1:cfg.nu,replaceDuty(k,sprintf('TPC_Duties/%d',k));end
  else,replaceDuty(1,'TPC_NN/1');end
 end
end
% Explicit trace: physical iL, voltage, load current and every duty command.
add_block('simulink/Signal Routing/Mux',[mdl '/TPC_RecordMux'],'Inputs',num2str(3+cfg.nu),'Position',[2400 100 2410 400]);
for k=1:3,add_line(mdl,[features{k} '/1'],sprintf('TPC_RecordMux/%d',k),'autorouting','on');end
for k=1:cfg.nu
 ph=get_param([mdl '/' cfg.activePwm{k}],'PortHandles');lh=get_param(ph.Inport(1),'Line');sp=source_port(lh);sink=get_param([mdl '/TPC_RecordMux'],'PortHandles');add_line(mdl,sp,sink.Inport(3+k),'autorouting','on');
end
logTs='2.5e-6';if strcmp(kind,'closed'),logTs='1e-7';end
add_block('simulink/Sinks/To Workspace',[mdl '/TPC_FullTrace'],'VariableName','TPC_trace','SaveFormat','Timeseries','MaxDataPoints','inf','SampleTime',logTs,'Position',[2450 200 2550 250]);add_line(mdl,'TPC_RecordMux/1','TPC_FullTrace/1','autorouting','on');
if strcmp(kind,'closed'),tpc_add_port_trace(mdl);end
% Remove abandoned controller experiments and all inherited diagnostic sinks.
tpc_clean_root(mdl);save_system(mdl,destination);
tpc_assert_topology(cfg.source,destination);
 function replaceDuty(k,srcSignal)
  pwm=[mdl '/' cfg.activePwm{k}];pp=get_param(pwm,'PortHandles');lh=get_param(pp.Inport(1),'Line');if lh~=-1,delete_line(lh);end
  old=[mdl '/TPC_Command_' num2str(k)];if getSimulinkBlockHandle(old)>0,delete_block(old);end
  lower=0;if isfield(cfg,'dutyMin'),lower=cfg.dutyMin(k);end
  sat=sprintf('TPC_DutyLimit_%d',k);add_block('simulink/Discontinuities/Saturation',[mdl '/' sat],'LowerLimit',num2str(lower,17),'UpperLimit',num2str(cfg.dutyMax(k),17),'Position',[2300 100+60*k 2350 130+60*k]);
  add_line(mdl,srcSignal,[sat '/1'],'autorouting','on');add_line(mdl,[sat '/1'],[cfg.activePwm{k} '/1'],'autorouting','on');
 end
end

function sp=source_port(lh)
sp=get_param(lh,'SrcPortHandle');parent=get_param(lh,'LineParent');
while sp<0&&~isempty(parent)&&parent>0
 lh=parent;sp=get_param(lh,'SrcPortHandle');parent=get_param(lh,'LineParent');
end
end
