function report=run_closed_loop()
% 本文件直接包含本步骤的计算过程；参数统一在 parameters.m 修改。
codeDir = fileparts(mfilename('fullpath'));
run(fullfile(codeDir, 'parameters.m'));

root=tpc_project_root();C=tpc_read_cases(fullfile(root,'config','target_cases.json'));
needed=unique({cfg.mapping.mode});
if isfield(cfg,'Co') && isfield(cfg,'warmupTime') && cfg.warmupTime>0
 for j=1:numel(needed)
  k=find(strcmp({C.id},needed{j}),1);assert(~isempty(k));
  assert(C(k).Co==cfg.Co && C(k).Ts==cfg.Ts,'Switch and component models differ.');
  S=load(fullfile(C(k).codeDir,'models','identified_model.mat'),'models');
  n=find(cellfun(@(x)x.Rload==cfg.Rload,S.models),1);assert(~isempty(n));
  C(k).nominalDuty=S.models{n}.steadyAnchor.u(:);
 end
end

[~,src]=fileparts(cfg.source);mdl=['TPC_SWITCH_' strrep(cfg.id,'_EXTRA','')];dest=fullfile(cfg.caseDir,'circuit',[mdl '.slx']);if ~isfolder(fileparts(dest)),mkdir(fileparts(dest));end
assert(~bdIsLoaded(src)&&~bdIsLoaded(mdl));load_system(cfg.source);save_system(src,dest);close_system(src,0);load_system(dest);
warmup=0;if isfield(cfg,'warmupTime'),warmup=cfg.warmupTime;end
set_param(mdl,'ReturnWorkspaceOutputs','on','SignalLogging','off','Solver','ode23tb','MaxStep','1e-7','RelTol','1e-6','StopTime',num2str(warmup+max(cfg.events)+.01,17));
B=find_system(mdl,'SearchDepth',1,'Type','Block');
for k=1:numel(B)
 name=get_param(B{k},'Name');if contains(name,'Series RLC Branch')
  try,bt=get_param(B{k},'BranchType');rr=str2double(get_param(B{k},'Resistance'));catch,continue;end
  if strcmp(bt,'R')&&rr>=100,set_param(B{k},'Resistance',num2str(cfg.Rload,17));end
  if strcmp(bt,'C')&&isfield(cfg,'Co'),set_param(B{k},'Capacitance',num2str(cfg.Co,17));end
  if strcmp(bt,'L')&&isfield(cfg,'L'),set_param(B{k},'Inductance',num2str(cfg.L,17));end
 elseif strcmp(get_param(B{k},'BlockType'),'Step')&&warmup>0
  time=str2double(get_param(B{k},'Time'));if isfinite(time)&&time>0,set_param(B{k},'Time',num2str(time+warmup,17));end
 end
end
fixed=[mdl '/' sprintf('PWM Generator%c(DC-DC)4',10)];
if getSimulinkBlockHandle(fixed)>0
 ph=get_param(fixed,'PortHandles');lh=get_param(ph.Inport(1),'Line');if lh~=-1,delete_line(lh);end
 add_block('simulink/Sources/Constant',[mdl '/TPC_FixedS1'],'Value',num2str(cfg.fixedDutyS1,17),'Position',[1700 40 1750 70]);add_line(mdl,'TPC_FixedS1/1',[get_param(fixed,'Name') '/1'],'autorouting','on');
end
add_block('simulink/Sources/Constant',[mdl '/TPC_Reference'],'Value',num2str(cfg.Vref,17),'Position',[1800 400 1850 430]);
add_block('simulink/Signal Routing/Mux',[mdl '/TPC_Features'],'Inputs','4','Position',[1900 300 1910 450]);
features={'Current Measurement3','Voltage Measurement','Current Measurement1'};
for k=1:3,add_line(mdl,[features{k} '/1'],sprintf('TPC_Features/%d',k),'autorouting','on');end
add_line(mdl,'TPC_Reference/1','TPC_Features/4','autorouting','on');
if isfield(cfg,'feedbackTiming')&&strcmp(cfg.feedbackTiming,'sample_hold')
 add_block('simulink/Discrete/Zero-Order Hold',[mdl '/TPC_FeedbackDelay'],'SampleTime',num2str(cfg.Ts,17),'Position',[1950 350 2000 390]);
else
 add_block('simulink/Discrete/Unit Delay',[mdl '/TPC_FeedbackDelay'],'SampleTime',num2str(cfg.Ts,17),'InitialCondition',['[0;0;0;' num2str(cfg.Vref) ']'],'Position',[1950 350 2000 390]);
end
add_line(mdl,'TPC_Features/1','TPC_FeedbackDelay/1','autorouting','on');
if warmup>0
 add_block('simulink/Sources/Clock',[mdl '/TPC_InitClock']);add_block('simulink/Sources/Constant',[mdl '/TPC_InitEnd'],'Value',num2str(warmup,17));
 add_block('simulink/Logic and Bit Operations/Relational Operator',[mdl '/TPC_Initializing'],'Operator','<');
 add_line(mdl,'TPC_InitClock/1','TPC_Initializing/1');add_line(mdl,'TPC_InitEnd/1','TPC_Initializing/2');
end
networkSources=struct('mode',{},'head',{},'file',{},'hidden',{},'networkFingerprint',{});
for k=1:numel(cfg.mapping)
 map=cfg.mapping(k);j=find(strcmp({C.id},map.mode),1);S=load(fullfile(C(j).codeDir,'models','net_48_72_120.mat'),'net');N=S.net;
 assert(isequal([size(N.W1,1),size(N.W2,1)],C(j).hiddenSizes(:)'), 'Switch network does not match the component hiddenSizes; train that mode first.');
 networkSources(k)=struct('mode',map.mode,'head',map.head,'file',fullfile(C(j).codeDir,'models','net_48_72_120.mat'),'hidden',[size(N.W1,1),size(N.W2,1)],'networkFingerprint',tpc_fingerprint(N));
 if isfield(N,'W3'),N.W3=N.W3(map.head,:);N.b3=N.b3(map.head);else,N.W2=N.W2(map.head,:);N.b2=N.b2(map.head);end;name=sprintf('TPC_NN_%d',k);tpc_add_relu_block(mdl,name,N);add_line(mdl,'TPC_FeedbackDelay/1',[name '/1'],'autorouting','on');
 output=[name '/1'];
 if warmup>0
  init=sprintf('TPC_InitDuty_%d',k);select=sprintf('TPC_InitSelect_%d',k);
  add_block('simulink/Sources/Constant',[mdl '/' init],'Value',num2str(C(j).nominalDuty(map.head),17));
  add_block('simulink/Signal Routing/Switch',[mdl '/' select],'Criteria','u2 ~= 0');
  add_line(mdl,[init '/1'],[select '/1']);add_line(mdl,'TPC_Initializing/1',[select '/2']);add_line(mdl,output,[select '/3']);output=[select '/1'];
 end
 lower=0;if isfield(C(j),'dutyMin')&&~isempty(C(j).dutyMin),lower=C(j).dutyMin(map.head);end;sat=sprintf('TPC_DutyLimit_%d',k);add_block('simulink/Discontinuities/Saturation',[mdl '/' sat],'LowerLimit',num2str(lower,17),'UpperLimit',num2str(C(j).dutyMax(map.head),17),'Position',[2300 100+60*k 2350 130+60*k]);add_line(mdl,output,[sat '/1'],'autorouting','on');
 pp=get_param([mdl '/' map.pwm],'PortHandles');lh=get_param(pp.Inport(1),'Line');if lh~=-1,delete_line(lh);end;add_line(mdl,[sat '/1'],[map.pwm '/1'],'autorouting','on');
end
add_block('simulink/Signal Routing/Mux',[mdl '/TPC_RecordMux'],'Inputs',num2str(3+numel(cfg.mapping)),'Position',[2450 100 2460 450]);
for k=1:3,add_line(mdl,[features{k} '/1'],sprintf('TPC_RecordMux/%d',k),'autorouting','on');end
for k=1:numel(cfg.mapping),add_line(mdl,sprintf('TPC_DutyLimit_%d/1',k),sprintf('TPC_RecordMux/%d',k+3),'autorouting','on');end
add_block('simulink/Sinks/To Workspace',[mdl '/TPC_FullTrace'],'VariableName','TPC_trace','SaveFormat','Timeseries','MaxDataPoints','inf','SampleTime','1e-7','Position',[2500 200 2600 250]);add_line(mdl,'TPC_RecordMux/1','TPC_FullTrace/1','autorouting','on');
tpc_add_port_trace(mdl);tpc_clean_root(mdl);save_system(mdl,dest);
tpc_assert_topology(cfg.source,dest);
fprintf('SWITCH_SIM_START %s\n',cfg.id);out=sim(mdl);ts=out.get('TPC_trace');t=ts.Time(:);a=squeeze(ts.Data);if size(a,1)~=numel(t),a=a';end
initializationPeak=[];if warmup>0,initializationPeak=max(abs(a(t<warmup,1)));mask=t>=warmup-1e-10;t=t(mask)-warmup;a=a(mask,:);end
assert(all(isfinite(a),'all'));report=tpc_response_metrics(t,a,cfg.Vref,cfg.events);report.id=cfg.id;report.networkSources=networkSources;report.originalTopologyPreserved=true;report.controllers={cfg.mapping.mode};report.note=[report.note ' All source scheduling Steps and auxiliary switches are retained.'];
portTrace=out.get('TPC_ports');if warmup>0,tt=portTrace.Time(:);pa=squeeze(portTrace.Data);if size(pa,1)~=numel(tt),pa=pa';end;mask=tt>=warmup-1e-10;portTrace=timeseries(pa(mask,:),tt(mask)-warmup);end
ud=get_param([mdl '/TPC_PortLog'],'UserData');report.ports=tpc_port_metrics(portTrace,ud,cfg);report.controlTs=cfg.Ts;
report.initializationSeconds=warmup;report.initializationPeakCurrentA=initializationPeak;report.startupPeakIsAcceptanceGate=false;
report.feedbackWindowPeakAbsoluteCurrent=max(abs(a(:,1)));report.fullRunPeakCurrentA=max([initializationPeak(:);report.feedbackWindowPeakAbsoluteCurrent]);report.currentWithin20AIncludingStartup=report.fullRunPeakCurrentA<=20;
if warmup>0,report.note=[report.note ' Declared nominal-duty initialization precedes plotted feedback/switch windows; startup peak is informational per user instruction.'];end
save(fullfile(cfg.codeDir,'results','switching_dynamic.mat'),'t','a','report','cfg','portTrace','ud','-v7.3');fid=fopen(fullfile(cfg.codeDir,'results','switching_dynamic.json'),'w');fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
fig=figure('Visible','off','Position',[100 100 1200 850]);tiledlayout(3,1);nexttile;plot(t*1e3,a(:,2));hold on;yline(cfg.Vref,'r--');for te=cfg.events(:)',xline(te*1e3,'k:');end;xlim([cfg.events(1)-.002,cfg.events(end)+.002]*1e3);ylabel('Vo / V');title(cfg.id,'Interpreter','none');grid on;
nexttile;plot(t*1e3,a(:,1));xlim([cfg.events(1)-.002,cfg.events(end)+.002]*1e3);ylabel('iL / A');grid on;
nexttile;plot(t*1e3,a(:,3));xlim([cfg.events(1)-.002,cfg.events(end)+.002]*1e3);ylabel('io / A');xlabel('Time / ms');grid on;exportgraphics(fig,fullfile(cfg.codeDir,'results','mode_switching.png'),'Resolution',180);close(fig);
tpc_readable_layout(mdl);save_system(mdl);close_system(mdl,0);disp(report);fprintf('SWITCH_SIM_COMPLETE %s\n',cfg.id);
tpc_publication_figures(codeDir,'closed');
tpc_show_figures(codeDir,'summary');

end
