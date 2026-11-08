function tpc_collect_continuous(cfg,file)
% One uninterrupted SPS solve avoids native OperatingPoint restore failures.
records={};anchors=cell(numel(cfg.Rloads),1);
for j=1:numel(cfg.Rloads)
 R=cfg.Rloads(j);mdl=tpc_make_plant(cfg,R,'open');u=cfg.nominalDuty(:)';commands=u;
 for h=1:cfg.nu
  q=u;q(h)=min(cfg.dutyMax(h),q(h)+.015);commands(end+1,:)=q;q=u;q(h)=max(0,q(h)-.015);commands(end+1,:)=q;commands(end+1,:)=u; %#ok<AGROW>
 end
 times=[0;cfg.warmupTime+(0:size(commands,1)-1)'*cfg.segmentTime];values=[u;commands];stop=times(end)+cfg.segmentTime;
 in=Simulink.SimulationInput(mdl);
 for h=1:cfg.nu
  old=sprintf('TPC_Command_%d',h);ph=get_param([mdl '/' old],'PortHandles');lh=get_param(ph.Outport(1),'Line');dst=get_param(lh,'DstPortHandle');delete_line(lh);delete_block([mdl '/' old]);
  variable=sprintf('TPC_excitation_%d',h);add_block('simulink/Sources/From Workspace',[mdl '/' old],'VariableName',variable,'Interpolate','off','OutputAfterFinalValue','Holding final value','Position',[1800 100+60*h 1850 130+60*h]);
  pp=get_param([mdl '/' old],'PortHandles');for v=dst(:)',if v>0,add_line(mdl,pp.Outport(1),v,'autorouting','on');end;end
  in=in.setVariable(variable,[times,values(:,h)]);
 end
 in=in.setModelParameter('StartTime','0','StopTime',num2str(stop,17),'SaveFinalState','off');fprintf('CONTINUOUS_OPEN_START %s R=%g duration=%g\n',cfg.id,R,stop);out=sim(in);
 ts=out.get('TPC_trace');t=ts.Time(:);a=squeeze(ts.Data);if size(a,1)~=numel(t),a=a';end;assert(all(isfinite(a),'all'));
 warm=t>=cfg.warmupTime-.02&t<cfg.warmupTime;
 records{end+1}=struct('Rload',R,'u',u,'t',t(warm),'a',a(warm,:)); %#ok<AGROW>
 ii=warm&abs(t/cfg.Ts-round(t/cfg.Ts))<1e-5;anchors{j}=struct('x',mean(a(ii,1:2),1),'u',u,'Rload',R,'window',[cfg.warmupTime-.02,cfg.warmupTime]);
 for k=1:size(commands,1),w=t>=times(k+1)&t<=times(k+1)+cfg.segmentTime;records{end+1}=struct('Rload',R,'u',commands(k,:),'t',t(w),'a',a(w,:));end %#ok<AGROW>
 fprintf('CONTINUOUS_OPEN_COMPLETE %s R=%g anchor=%s\n',cfg.id,R,mat2str(anchors{j}.x,8));close_system(mdl,0);
end
save(file,'records','anchors','cfg','-v7.3');
end
