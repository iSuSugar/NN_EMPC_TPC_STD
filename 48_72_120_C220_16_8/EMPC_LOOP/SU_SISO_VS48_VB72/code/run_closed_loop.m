function report=run_closed_loop()
% Self-contained native Simulink NN model; no interpreted MATLAB controller.
% 本文件直接包含本步骤的计算过程；参数统一在 parameters.m 修改。
codeDir = fileparts(mfilename('fullpath'));
run(fullfile(codeDir, 'parameters.m'));
o=initialization;
%% 读取本工况网络与初始化设置
N=load(fullfile(codeDir,'models','net_48_72_120.mat'),'net');
assert(size(N.net.W1,1)==cfg.hiddenSizes(1)&&size(N.net.W2,1)==cfg.hiddenSizes(2),'Saved network does not match hiddenSizes; train this copy first.');
test=cfg;
test.caseDir=fileparts(codeDir);test.nominalDuty=o.warmupDuty;warm=o.warmup;stop=warm+max(cfg.events)+.01;
%% 构建实际开关电路
mdl=tpc_make_plant(test,cfg.Rloads(1),'closed',N.net);
B=find_system(mdl,'SearchDepth',1,'BlockType','Step');
for k=1:numel(B),time=str2double(get_param(B{k},'Time'));j=find(abs(time-cfg.events(:))<1e-10,1);if ~isempty(j),set_param(B{k},'Time',num2str(time+warm,17));end;end
set_param(mdl,'StopTime',num2str(stop,17));
add_block('simulink/Sources/Clock',[mdl '/TPC_InitClock']);add_block('simulink/Sources/Constant',[mdl '/TPC_InitEnd'],'Value',num2str(warm,17));
add_block('simulink/Logic and Bit Operations/Relational Operator',[mdl '/TPC_Initializing'],'Operator','<');
add_line(mdl,'TPC_InitClock/1','TPC_Initializing/1');add_line(mdl,'TPC_InitEnd/1','TPC_Initializing/2');
times=(0:round(stop/cfg.Ts))'*cfg.Ts;commands=repmat(o.warmupDuty(:)',numel(times),1);
if isfield(o,'startupRamp')&&o.startupRamp>0
 phase=min(1,times/o.startupRamp);target=phase*cfg.Vref;
 if strcmp(cfg.id,'SISO_VS_VO')
  commands=target./(cfg.Vs+target)+phase*(o.warmupDuty-cfg.Vref/(cfg.Vs+cfg.Vref));
 elseif any(strcmp(cfg.id,{'SISO_VB_VO','SISO_VS_VB'}))
  supply=cfg.Vb;if strcmp(cfg.id,'SISO_VS_VB'),supply=cfg.Vs;end
  commands=zeros(size(times));mask=target>supply;bp=(target(mask)-supply)/(cfg.Vref-supply);
  commands(mask)=1-supply./target(mask)+bp*(o.warmupDuty-(1-supply/cfg.Vref));
 else,commands=phase*o.warmupDuty(:)';end
end
workspace=get_param(mdl,'ModelWorkspace');
for k=1:cfg.nu
 sat=[mdl '/TPC_DutyLimit_' num2str(k)];ph=get_param(sat,'PortHandles');line=get_param(ph.Inport(1),'Line');source=get_param(line,'SrcPortHandle');delete_line(line);
 init=sprintf('TPC_InitCommand_%d',k);select=sprintf('TPC_InitSelect_%d',k);variable=sprintf('TPC_InitValues_%d',k);
 assignin(workspace,variable,[times commands(:,k)]);
 add_block('simulink/Sources/From Workspace',[mdl '/' init],'VariableName',variable,'SampleTime',num2str(cfg.Ts,17),'Interpolate','off','OutputAfterFinalValue','Holding final value');
 add_block('simulink/Signal Routing/Switch',[mdl '/' select],'Criteria','u2 ~= 0');p=get_param([mdl '/' select],'PortHandles');
 add_line(mdl,source,p.Inport(3),'autorouting','on');add_line(mdl,[init '/1'],[select '/1']);add_line(mdl,'TPC_Initializing/1',[select '/2']);add_line(mdl,[select '/1'],['TPC_DutyLimit_' num2str(k) '/1']);
 if isfield(o,'startupRamp')&&o.startupRamp>0,set_param(sat,'LowerLimit','0');end
end
if isfield(o,'startupRamp')&&o.startupRamp>0&&~strcmp(cfg.id,'SISO_VS_VO')
 name=['PWM Generator' newline '(DC-DC)'];level=1;duration=o.startupRamp*cfg.Vb/cfg.Vref;
 if strcmp(cfg.id,'SISO_VS_VB'),name=['PWM Generator' newline '(DC-DC)2'];duration=o.startupRamp*cfg.Vs/cfg.Vref;end
 if strcmp(cfg.id,'SIDO'),name=cfg.fixedPwm;level=cfg.fixedDutyS1;duration=o.startupRamp;end
 if strcmp(cfg.id,'DISO'),name=['PWM Generator' newline '(DC-DC)3'];level=.5;duration=o.startupRamp;end
 ph=get_param([mdl '/' name],'PortHandles');line=get_param(ph.Inport(1),'Line');if line~=-1,delete_line(line);end
 assignin(workspace,'TPC_AuxInitValues',[0 0;duration level;stop level]);
 add_block('simulink/Sources/From Workspace',[mdl '/TPC_AuxInit'],'VariableName','TPC_AuxInitValues','SampleTime',num2str(cfg.Ts,17),'Interpolate','on','OutputAfterFinalValue','Holding final value');
 add_line(mdl,'TPC_AuxInit/1',[name '/1']);
end
for k=1:2
 name='TPC_NativeRaw';variable='TPC_nativeRaw';source='TPC_NN/1';
 if k==2,name='TPC_NativeFeatures';variable='TPC_nativeFeatures';source='TPC_FeedbackDelay/1';end
 add_block('simulink/Sinks/To Workspace',[mdl '/' name],'VariableName',variable,'SaveFormat','Timeseries','MaxDataPoints','inf','SampleTime',num2str(cfg.Ts,17));add_line(mdl,source,[name '/1']);
end
%% 运行实际电路仿真
tpc_clean_root(mdl);save_system(mdl);fprintf('NATIVE_CANDIDATE_START %s\n',cfg.id);out=sim(mdl);
%% 读取波形并统计指标
ts=out.get('TPC_trace');tt=ts.Time(:);aa=squeeze(ts.Data);if size(aa,1)~=numel(tt),aa=aa';end
initializationPeak=max(abs(aa(tt<warm,1)));mask=tt>=warm-1e-10;t=tt(mask)-warm;a=aa(mask,:);
report=tpc_response_metrics(t,a,cfg.Vref,cfg.events);report.id=cfg.id;report.nnArchitecture=[size(N.net.W1,1),size(N.net.W2,1)];report.nnFile=fullfile(codeDir,'models','net_48_72_120.mat');report.controlTs=cfg.Ts;report.nativeNNBlocks=true;report.startupPeakIsAcceptanceGate=false;report.initializationSeconds=warm;report.initializationPeakCurrentA=initializationPeak;
report.feedbackWindowPeakAbsoluteCurrent=max(abs(a(:,1)));report.fullRunPeakCurrentA=max(initializationPeak,report.feedbackWindowPeakAbsoluteCurrent);
report.currentWithin20AIncludingStartup=report.fullRunPeakCurrentA<=20;
pt=out.get('TPC_ports');ptt=pt.Time(:);pa=squeeze(pt.Data);if size(pa,1)~=numel(ptt),pa=pa';end;mask=ptt>=warm-1e-10;portTrace=timeseries(pa(mask,:),ptt(mask)-warm);
portMetadata=get_param([mdl '/TPC_PortLog'],'UserData');report.ports=tpc_port_metrics(portTrace,portMetadata,cfg);
f=out.get('TPC_nativeFeatures');u=out.get('TPC_nativeRaw');ct=f.Time(:);features=squeeze(f.Data);duty=squeeze(u.Data);
if size(features,1)~=numel(ct),features=features';end;if cfg.nu==1,duty=duty(:);elseif size(duty,1)~=numel(ct),duty=duty';end
mask=ct>=warm-1e-10;ct=ct(mask);features=features(mask,:);duty=duty(mask,:);ratio=features(:,2)./max(features(:,3),1e-9);[~,ix]=min(abs(ratio-cfg.Rloads(:)'),[],2);loads=cfg.Rloads(ix);loads=loads(:);
controllerLog=[ct features duty loads nan(numel(ct),1) zeros(numel(ct),1)];
save(fullfile(codeDir,'results','native_switching_dynamic.mat'),'t','a','report','cfg','controllerLog','portTrace','portMetadata','-v7.3');
fid=fopen(fullfile(codeDir,'results','native_switching_dynamic.json'),'w');fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
copyfile(fullfile(codeDir,'results','native_switching_dynamic.mat'),fullfile(codeDir,'results','switching_dynamic.mat'));
copyfile(fullfile(codeDir,'results','native_switching_dynamic.json'),fullfile(codeDir,'results','switching_dynamic.json'));
% Public entry points show the unified publication suite after verification.
% Retain the historical PNG here without opening a duplicate plain figure.
showFigure=false;visibility='off';
fig=figure('Name',[cfg.id ' closed-loop results'],'NumberTitle','off','Visible',visibility,'Position',[100 100 1100 800]);tiledlayout(3,1);
nexttile;plot(t*1e3,a(:,2));hold on;yline(cfg.Vref,'r--');ylabel('Controlled voltage / V');title([cfg.id ': native NN blocks; initialization excluded'],'Interpreter','none');grid on;
nexttile;plot(t*1e3,a(:,1));ylabel('Inductor current / A');grid on;
nexttile;plot(t*1e3,a(:,4:end));ylabel('Applied duty');xlabel('Time since feedback enable / ms');grid on;
exportgraphics(fig,fullfile(codeDir,'results','switching_dynamic.png'),'Resolution',160);
if showFigure,drawnow;else,close(fig);end
fprintf('RESULT_PLOT %s\n',fullfile(codeDir,'results','switching_dynamic.png'));
tpc_readable_layout(mdl);save_system(mdl);close_system(mdl,0);fprintf('NATIVE_CANDIDATE_COMPLETE %s\n',cfg.id);disp(report);
%% 核对真实状态上的网络与EMPC占空比
tpc_verify_candidate_nn(cfg,fullfile(codeDir,'results','native_switching_dynamic.mat'),'NN_native_trajectory');
tpc_publication_figures(codeDir,'closed');
tpc_show_figures(codeDir,'summary');

end
