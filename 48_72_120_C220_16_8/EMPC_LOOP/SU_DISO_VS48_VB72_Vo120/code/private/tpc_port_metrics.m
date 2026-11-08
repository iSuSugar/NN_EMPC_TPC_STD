function m=tpc_port_metrics(ts,ud,cfg)
names=ud.portTraceNames;t=ts.Time(:);a=squeeze(ts.Data);if size(a,1)~=numel(t),a=a';end
edges=[0;cfg.events(:);t(end)];windows=cell(numel(edges)-1,1);
for k=1:numel(windows)
 stop=edges(k+1);start=max(edges(k)+.001,stop-.001);w=t>=start&t<stop;
 windows{k}=struct('timeWindow',[start stop],'meanMeasurements',mean(a(w,:),1));
 if isfield(cfg,'id')&&strcmp(cfg.id,'DISO')
  first=find(strcmp(names,'Mosfet1_gate'),1);parallel=find(strcmp(names,'Mosfet5_gate'),1);
  if ~isempty(first)&&~isempty(parallel)
   windows{k}.effectiveUpperSwitchDuty=mean(a(w,first)>.5|a(w,parallel)>.5);
   windows{k}.effectiveGateMeaning='MOSFET1 and MOSFET5 share both electrical nodes; union of the two non-overlapping gate pulse trains.';
  end
 end
end
m=struct('channelNames',{names},'windows',{windows},'measurementConvention','Current Measurement4: Vs positive terminal to converter; Current Measurement7: Vb positive terminal to converter in SIDO/DISO and switching circuits. Gates are actual binary gate signals, not duty commands.');
if isfield(cfg,'id')&&(any(strcmp(cfg.id,{'SIDO','DISO'}))||isfield(cfg,'mapping'))
 is=find(strcmp(names,'Current Measurement4'));ib=find(strcmp(names,'Current Measurement7'));ok=true;
 modes=repmat({cfg.id},numel(windows),1);if isfield(cfg,'mapping'),parts=strsplit(cfg.id,'_');modes=parts(1:numel(windows));end
 for k=1:numel(windows)
  v=windows{k}.meanMeasurements;
  if strcmp(modes{k},'SIDO'),matches=v(is)>0&&v(ib)<-.01;elseif strcmp(modes{k},'DISO'),matches=v(is)>0&&v(ib)>.01;else,matches=v(is)>0&&abs(v(ib))<.01;end
  m.windows{k}.expectedMode=modes{k};m.windows{k}.requestedPowerDirectionConfirmed=matches;ok=ok&&matches;
 end
 m.requestedPowerDirectionConfirmed=ok;
end
end
