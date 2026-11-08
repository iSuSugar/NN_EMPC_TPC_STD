function names=tpc_add_port_trace(mdl)
% Observe existing measurements and actual gate signals; no power-network edits.
names={};signals={};
for c={'Current Measurement4','Current Measurement7'}
 if getSimulinkBlockHandle([mdl '/' c{1}])>0,names{end+1}=c{1};signals{end+1}=[c{1} '/1'];end
end
for c={'Mosfet','Mosfet1','Mosfet2','Mosfet5'}
 block=[mdl '/' c{1}];if getSimulinkBlockHandle(block)<0,continue;end
 ph=get_param(block,'PortHandles');if isempty(ph.Inport),continue;end
 lh=get_param(ph.Inport(1),'Line');if lh<0,continue;end
 sp=get_param(lh,'SrcPortHandle');parent=get_param(lh,'LineParent');
 while sp<0&&~isempty(parent)&&parent>0,lh=parent;sp=get_param(lh,'SrcPortHandle');parent=get_param(lh,'LineParent');end
 cv=['TPC_GateDouble_' c{1}];add_block('simulink/Signal Attributes/Data Type Conversion',[mdl '/' cv],'OutDataTypeStr','double','Position',[2700 100+60*numel(names) 2750 130+60*numel(names)]);
 pp=get_param([mdl '/' cv],'PortHandles');add_line(mdl,sp,pp.Inport(1),'autorouting','on');names{end+1}=[c{1} '_gate'];signals{end+1}=[cv '/1'];
end
add_block('simulink/Signal Routing/Mux',[mdl '/TPC_PortMux'],'Inputs',num2str(numel(names)),'Position',[2800 100 2810 450]);
for k=1:numel(names),add_line(mdl,signals{k},sprintf('TPC_PortMux/%d',k),'autorouting','on');end
add_block('simulink/Sinks/To Workspace',[mdl '/TPC_PortLog'],'VariableName','TPC_ports','SaveFormat','Timeseries','MaxDataPoints','inf','SampleTime','1e-7','Position',[2850 200 2950 240]);add_line(mdl,'TPC_PortMux/1','TPC_PortLog/1','autorouting','on');
add_block('simulink/Sinks/Scope',[mdl '/TPC_Scope'],'Position',[2850 480 2900 520]);add_line(mdl,'TPC_RecordMux/1','TPC_Scope/1','autorouting','on');
set_param([mdl '/TPC_PortLog'],'UserData',struct('portTraceNames',{names}),'UserDataPersistent','on');
end
