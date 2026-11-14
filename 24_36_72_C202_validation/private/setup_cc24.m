function setup_cc24(mdl,cfg)
% Ideal CC sink with 5V compliance emulation. Ramp load after initial voltage build-up.
name='Series RLC Branch3';if strcmp(cfg.id,'SISO_VS_VB'),name='Series RLC Branch1';elseif strcmp(cfg.id,'DISO'),name='Series RLC Branch5';end
B=find_system(mdl,'SearchDepth',1,'Type','Block');candidates={};
for k=1:numel(B)
 if ~contains(get_param(B{k},'Name'),'Series RLC Branch'),continue;end
 if strcmp(get_param(B{k},'BranchType'),'R')&&str2double(get_param(B{k},'Resistance'))==144,candidates{end+1}=B{k};end
end
old=[mdl '/' name];assert(any(strcmp(candidates,old)),'Expected load resistor %s',name);pos=get_param(old,'Position');orient=get_param(old,'Orientation');ph=get_param(old,'PortHandles');
direct=strcmp(cfg.id,'DISO');
connections=cell(2,1);ports=[ph.LConn(:);ph.RConn(:)];assert(numel(ports)==2);
for k=1:2
 lh=get_param(ports(k),'Line');p=get_param(lh,'SrcPortHandle');q=get_param(lh,'DstPortHandle');others=[p(:);q(:)];others=others(others>0&others~=ports(k));connections{k}=others;
end
if direct
 for k=1:numel(candidates),set_param(candidates{k},'Resistance','1e9');end
 voltage=get_param([mdl '/' cfg.voltageSensor],'PortHandles');returnPath=get_param([mdl '/Current Measurement1'],'PortHandles');connections={voltage.LConn(2);returnPath.RConn(1)};pos=[1450 700 1490 780];
else,delete_block(old);end
new=[mdl '/CC_Load'];add_block('powerlib/Electrical Sources/Controlled Current Source',new,'Position',pos,'Orientation',orient);p=get_param(new,'PortHandles');np=[p.LConn(:);p.RConn(:)];
for k=1:2
 if get_param(np(k),'Line')<0,assert(~isempty(connections{k}));add_line(mdl,connections{k}(1),np(k),'autorouting','on');end
end
add_block('simulink/Sources/From Workspace',[mdl '/CC_Setpoint'],'VariableName','LOAD_SEQUENCE','Interpolate','off','OutputAfterFinalValue','Holding final value');mw=get_param(mdl,'ModelWorkspace');assignin(mw,'LOAD_SEQUENCE',[0 0;.03 .5;.06 1;.08 .5;.09 .5]);
add_block('simulink/Math Operations/Gain',[mdl '/CC_VoltageScale'],'Gain','.2');add_line(mdl,[cfg.voltageSensor '/1'],'CC_VoltageScale/1','autorouting','on');
add_block('simulink/Discrete/Unit Delay',[mdl '/CC_VoltageMemory'],'SampleTime','1e-6','InitialCondition','0');add_line(mdl,'CC_VoltageScale/1','CC_VoltageMemory/1');
add_block('simulink/Discontinuities/Saturation',[mdl '/CC_Compliance'],'LowerLimit','0','UpperLimit','1');add_line(mdl,'CC_VoltageMemory/1','CC_Compliance/1');
add_block('simulink/Math Operations/Product',[mdl '/CC_CurrentCommand'],'Inputs','**');add_line(mdl,'CC_Setpoint/1','CC_CurrentCommand/1');add_line(mdl,'CC_Compliance/1','CC_CurrentCommand/2');
add_block('simulink/Math Operations/Gain',[mdl '/CC_SinkPolarity'],'Gain','-1');add_line(mdl,'CC_CurrentCommand/1','CC_SinkPolarity/1');add_line(mdl,'CC_SinkPolarity/1','CC_Load/1');
end
