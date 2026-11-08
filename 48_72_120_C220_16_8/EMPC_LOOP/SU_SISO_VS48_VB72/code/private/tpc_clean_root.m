function tpc_clean_root(mdl)
B=find_system(mdl,'SearchDepth',1,'Type','Block');keep=false(numel(B),1);queue=[];
for k=1:numel(B)
 if strcmp(B{k},mdl),keep(k)=true;continue;end
 ph=get_param(B{k},'PortHandles');name=get_param(B{k},'Name');electrical=~isempty(ph.LConn)||~isempty(ph.RConn);
 if electrical||strcmp(name,'powergui')||startsWith(name,'TPC_'),keep(k)=true;queue=[queue,k];end %#ok<AGROW>
end
while ~isempty(queue)
 k=queue(1);queue(1)=[];ph=get_param(B{k},'PortHandles');
 for ip=ph.Inport(:)'
  lh=get_param(ip,'Line');if lh==-1,continue;end;sp=source_port(lh);if sp==-1,continue;end
  parent=get_param(sp,'Parent');j=find(strcmp(B,parent),1);if ~isempty(j)&&~keep(j),keep(j)=true;queue(end+1)=j;end %#ok<AGROW>
 end
end
for k=1:numel(B),if ~keep(k),delete_block(B{k});end;end
% Remove isolated diagram stubs with no port, parent or child; no electrical edge is removed.
lines=find_system(mdl,'FindAll','on','SearchDepth',1,'Type','line');
for ll=lines(:)'
 try
  if strcmp(get_param(ll,'LineType'),'signal')&&get_param(ll,'SrcPortHandle')<0&&~any(get_param(ll,'LineParent')>0),delete_line(ll);end
 catch
 end
end
B=find_system(mdl,'SearchDepth',1,'Type','Block');n=0;
for k=1:numel(B)
 if strcmp(B{k},mdl),continue;end
 ph=get_param(B{k},'PortHandles');
 for op=ph.Outport(:)'
  lh=get_param(op,'Line');if lh~=-1,prune(lh);end;lh=get_param(op,'Line');
  if lh==-1,n=n+1;nm=sprintf('TPC_Unused_%d',n);while getSimulinkBlockHandle([mdl '/' nm])>0,n=n+1;nm=sprintf('TPC_Unused_%d',n);end;add_block('simulink/Sinks/Terminator',[mdl '/' nm],'Position',[2700 30*n 2720 30*n+20]);pp=get_param([mdl '/' nm],'PortHandles');add_line(mdl,op,pp.Inport(1),'autorouting','on');end
 end
 if contains(get_param(B{k},'Name'),'Mosfet')
  for ip=ph.Inport(:)'
   if get_param(ip,'Line')==-1,n=n+1;nm=sprintf('TPC_Off_%d',n);while getSimulinkBlockHandle([mdl '/' nm])>0,n=n+1;nm=sprintf('TPC_Off_%d',n);end;add_block('simulink/Sources/Constant',[mdl '/' nm],'Value','0','Position',[2800 30*n 2840 30*n+20]);pp=get_param([mdl '/' nm],'PortHandles');add_line(mdl,pp.Outport(1),ip,'autorouting','on');end
  end
 end
end
end
function prune(lh)
try,children=get_param(lh,'LineChildren');catch,return;end
for child=children(children>0)',prune(child);end
try,children=get_param(lh,'LineChildren');dest=get_param(lh,'DstPortHandle');catch,return;end
if ~any(children>0)&&~any(dest>0),delete_line(lh);end
end

function sp=source_port(lh)
sp=get_param(lh,'SrcPortHandle');parent=get_param(lh,'LineParent');
while sp<0&&~isempty(parent)&&parent>0
 lh=parent;sp=get_param(lh,'SrcPortHandle');parent=get_param(lh,'LineParent');
end
end
