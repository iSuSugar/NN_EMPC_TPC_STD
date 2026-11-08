function tpc_readable_layout(mdl)
% 仅整理显示层次和信号走线；功率元件、参数、算法和采样周期不变。
% 在构建/仿真读取日志之后调用，避免改变构建阶段按顶层名称查找模块的方式。
if getSimulinkBlockHandle([mdl '/TPC_Controller'])>0
 finishRouting(mdl);return;
end
B=find_system(mdl,'SearchDepth',1,'Type','Block');control=[];logs=[];
for k=1:numel(B)
 if strcmp(B{k},mdl),continue;end
 n=get_param(B{k},'Name');if ~startsWith(n,'TPC_'),continue;end
 if startsWith(n,'TPC_Unused_')||startsWith(n,'TPC_Off_'),continue;end
 if any(strcmp(n,{'TPC_RecordMux','TPC_FullTrace','TPC_PortMux','TPC_PortLog','TPC_Scope','TPC_NativeRaw','TPC_NativeFeatures'}))||startsWith(n,'TPC_GateDouble_')
  logs(end+1)=get_param(B{k},'Handle'); %#ok<AGROW>
 else
  control(end+1)=get_param(B{k},'Handle'); %#ok<AGROW>
 end
end
if ~isempty(control),Simulink.BlockDiagram.createSubsystem(control,'Name','TPC_Controller');end
if ~isempty(logs),Simulink.BlockDiagram.createSubsystem(logs,'Name','TPC_Logging');end
% Preserve the original power-stage drawing. Put the new functions below it.
B=find_system(mdl,'SearchDepth',1,'Type','Block');bottom=0;left=inf;right=0;
for k=1:numel(B)
 if strcmp(B{k},mdl)||startsWith(get_param(B{k},'Name'),'TPC_'),continue;end
 p=get_param(B{k},'Position');bottom=max(bottom,p(4));left=min(left,p(1));right=max(right,p(3));
end
if ~isfinite(left),left=100;end
subNames={'TPC_Controller','TPC_Logging'};
colors={'[0.85, 0.93, 1.0]','[1.0, 0.96, 0.80]'};
descriptions={'4 physical features -> NN -> startup select -> duty limits','Waveforms / port currents / gates / workspace logs'};
for k=1:2
 sub=[mdl '/' subNames{k}];if getSimulinkBlockHandle(sub)<0,continue;end
 Simulink.BlockDiagram.arrangeSystem(sub);
 x=left+(k-1)*480;set_param(sub,'Position',[x bottom+140 x+230 bottom+380], ...
  'BackgroundColor',colors{k},'ShowName','on');
 set_param(sub,'AttributesFormatString',descriptions{k});
end
% Collect ordinary Simulink edges touching the new functional groups.
B=find_system(mdl,'SearchDepth',1,'Type','Block');sources=[];sinks=[];
for k=1:numel(B)
 if strcmp(B{k},mdl),continue;end
 ph=get_param(B{k},'PortHandles');
 for ip=ph.Inport(:)'
  lh=get_param(ip,'Line');if lh<0,continue;end
  sp=source(lh);if sp<0,continue;end
  sn=get_param(get_param(sp,'Parent'),'Name');dn=get_param(B{k},'Name');
  if any(strcmp(sn,subNames))||any(strcmp(dn,subNames))
   sources(end+1)=sp;sinks(end+1)=ip; %#ok<AGROW>
  end
 end
end
% Local Goto/From tags replace long signal wires only. Electrical wires stay.
uniqueSources=unique(sources,'stable');
for k=1:numel(uniqueSources)
 sp=uniqueSources(k);dest=sinks(sources==sp);srcBlock=get_param(sp,'Parent');
 tag=sprintf('SIG_%03d',k);label=regexprep(get_param(srcBlock,'Name'),'[^A-Za-z0-9_]','_');
 if strcmp(label,'TPC_Controller'),label=['ControlOut' num2str(get_param(sp,'PortNumber'))];end
 label=strrep(label,'Current_Measurement','I_meas');label=strrep(label,'Voltage_Measurement','V_meas');
 tag=[tag '_' label];
 for ip=dest
  lh=get_param(ip,'Line');if lh>0,delete_line(mdl,sp,ip);end
 end
 p=get_param(sp,'Position');gn=sprintf('TPC_Send_%03d',k);
 add_block('simulink/Signal Routing/Goto',[mdl '/' gn],'GotoTag',tag,'TagVisibility','local','IconDisplay','Tag', ...
  'ShowName','off','Position',[p(1)+25 p(2)-9 p(1)+170 p(2)+9]);
 gp=get_param([mdl '/' gn],'PortHandles');add_line(mdl,sp,gp.Inport(1),'autorouting','on');
 for j=1:numel(dest)
  ip=dest(j);p=get_param(ip,'Position');fn=sprintf('TPC_Receive_%03d_%03d',k,j);
  add_block('simulink/Signal Routing/From',[mdl '/' fn],'GotoTag',tag,'IconDisplay','Tag','ShowName','off', ...
   'Position',[p(1)-180 p(2)-9 p(1)-25 p(2)+9]);
  fp=get_param([mdl '/' fn],'PortHandles');add_line(mdl,fp.Outport(1),ip,'autorouting','on');
 end
end
% Place generated terminators and fixed-off commands beside their connection.
B=find_system(mdl,'SearchDepth',1,'Type','Block');
for k=1:numel(B)
 if strcmp(B{k},mdl),continue;end;n=get_param(B{k},'Name');ph=get_param(B{k},'PortHandles');
 if startsWith(n,'TPC_Unused_')
  lh=get_param(ph.Inport(1),'Line');if lh>0,p=get_param(source(lh),'Position');set_param(B{k},'Position',[p(1)+30 p(2)-5 p(1)+40 p(2)+5],'ShowName','off');end
 elseif startsWith(n,'TPC_Off_')
  lh=get_param(ph.Outport(1),'Line');if lh>0,dp=get_param(lh,'DstPortHandle');dp=dp(dp>0);if ~isempty(dp),p=get_param(dp(1),'Position');set_param(B{k},'Position',[p(1)-70 p(2)-10 p(1)-40 p(2)+10],'ShowName','off');end;end
 end
end
note=Simulink.Annotation(mdl,'POWER STAGE: original electrical wiring above. Double-click TPC_Controller for the control chain; TPC_Logging only records signals. Matching tags are the same signal.');
note.Position=[left bottom+65 left+900 bottom+105];note.FontSize=12;
set_param(mdl,'ZoomFactor','FitSystem');
finishRouting(mdl);
fprintf('READABLE_LAYOUT %s: Controller + Logging; power stage preserved\n',mdl);
end
function finishRouting(mdl)
controller=[mdl '/TPC_Controller'];logging=[mdl '/TPC_Logging'];
if getSimulinkBlockHandle(controller)>0&&getSimulinkBlockHandle(logging)>0
 cp=get_param(controller,'Position');lp=get_param(logging,'Position');w=lp(3)-lp(1);lp([1 3])=[cp(1)+600 cp(1)+600+w];set_param(logging,'Position',lp);
end
blocks=find_system(mdl,'SearchDepth',1,'Type','Block');occupied=zeros(0,4);
for k=1:numel(blocks)
 if ~strcmp(blocks{k},mdl)&&~startsWith(get_param(blocks{k},'Name'),'TPC_'),occupied(end+1,:)=get_param(blocks{k},'Position');end %#ok<AGROW>
end
tags=find_system(mdl,'SearchDepth',1,'BlockType','Goto');
tags=[tags;find_system(mdl,'SearchDepth',1,'BlockType','From')];
cfg=tpc_load_case(fileparts(fileparts(mfilename('fullpath'))));
for k=1:numel(tags),set_param(tags{k},'IconDisplay','Tag','FontSize','9');end
gotos=find_system(mdl,'SearchDepth',1,'BlockType','Goto');
for k=1:numel(gotos)
 oldTag=get_param(gotos{k},'GotoTag');ph=get_param(gotos{k},'PortHandles');sp=source(get_param(ph.Inport(1),'Line'));
 n=get_param(get_param(sp,'Parent'),'Name');label=['Sig' num2str(k)];
 current='Current Measurement3';voltage='Voltage Measurement';loadCurrent='Current Measurement1';
 if isfield(cfg,'currentSensor'),current=cfg.currentSensor;end
 if isfield(cfg,'voltageSensor'),voltage=cfg.voltageSensor;end
 if isfield(cfg,'id')&&strcmp(cfg.id,'SISO_VS_VB'),loadCurrent='Current Measurement7';end
 if strcmp(n,current),label='iL';elseif strcmp(n,voltage),label='V';elseif strcmp(n,loadCurrent),label='Io';
 elseif strcmp(n,'TPC_Controller'),label=['C' num2str(get_param(sp,'PortNumber'))];
 elseif contains(n,'PWM'),label='gate';end
 newTag=sprintf('S%02d_%s',k,label);
 for j=1:numel(tags)
  if strcmp(get_param(tags{j},'GotoTag'),oldTag)
   set_param(tags{j},'GotoTag',newTag);p=get_param(tags{j},'Position');cy=round((p(2)+p(4))/2);
   if strcmp(get_param(tags{j},'BlockType'),'Goto')
    point=get_param(sp,'Position');base=[point(1)+25 point(2)-14 point(1)+130 point(2)+14];
    for offset=[0 -55 55 -100 100]
     rect=base+[0 offset 0 offset];hit=occupied(:,1)<rect(3)+8&occupied(:,3)>rect(1)-8&occupied(:,2)<rect(4)+8&occupied(:,4)>rect(2)-8;
     if ~any(hit),break;end
    end
    set_param(tags{j},'Position',rect);
   else
    fp=get_param(tags{j},'PortHandles');line=get_param(fp.Outport(1),'Line');dp=get_param(line,'DstPortHandle');dp=dp(dp>0);point=get_param(dp(1),'Position');
    set_param(tags{j},'Position',[point(1)-130 point(2)-14 point(1)-25 point(2)+14]);
   end
  end
 end
end
controller=[mdl '/TPC_Controller'];
if getSimulinkBlockHandle(controller)>0
 ph=get_param(controller,'PortHandles');ins=find_system(controller,'SearchDepth',1,'BlockType','Inport');
 for k=1:numel(ins)
  port=str2double(get_param(ins{k},'Port'));lh=get_param(ph.Inport(port),'Line');if lh<0,continue;end
  src=get_param(source(lh),'Parent');label='';
  if strcmp(get_param(src,'BlockType'),'From')
   tag=get_param(src,'GotoTag');if endsWith(tag,'_iL'),label='iL_A';elseif endsWith(tag,'_Io'),label='Io_A';elseif endsWith(tag,'_V'),label='Controlled_voltage_V';end
  end
  if ~isempty(label),set_param(ins{k},'Name',label);end
 end
 outs=find_system(controller,'SearchDepth',1,'BlockType','Outport');
 for k=1:numel(outs)
  phout=get_param(outs{k},'PortHandles');lh=get_param(phout.Inport(1),'Line');if lh<0,continue;end
  n=get_param(get_param(source(lh),'Parent'),'Name');label='';
  if startsWith(n,'TPC_DutyLimit_'),label=['Applied_d' extractAfter(n,'TPC_DutyLimit_')];
  elseif startsWith(n,'TPC_NN'),label=['Raw_network_' get_param(outs{k},'Port')];
  elseif strcmp(n,'TPC_FeedbackDelay'),label='Sampled_features';end
  if ~isempty(label),set_param(outs{k},'Name',label);end
 end
end
lines=find_system(mdl,'FindAll','on','SearchDepth',1,'Type','line');
signal=[];
for h=lines(:)'
 if strcmp(get_param(h,'LineType'),'signal')
  if get_param(h,'SrcPortHandle')<0&&~any(get_param(h,'LineParent')>0)
   delete_line(h);
  else,signal(end+1)=h;end %#ok<AGROW>
 end
end
if ~isempty(signal),Simulink.BlockDiagram.routeLine(signal);end
set_param(mdl,'ZoomFactor','FitSystem');
end
function sp=source(lh)
sp=get_param(lh,'SrcPortHandle');parent=get_param(lh,'LineParent');
while sp<0&&~isempty(parent)&&parent>0,lh=parent;sp=get_param(lh,'SrcPortHandle');parent=get_param(lh,'LineParent');end
end

