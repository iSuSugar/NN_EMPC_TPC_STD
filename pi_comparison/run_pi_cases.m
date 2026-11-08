function run_pi_cases(indices,controllers)
% Independent copies of the same saved switching circuit. Baseline is read-only.
if nargin<1,indices=1:5;end;if nargin<2,controllers={'NN','PI'};end
here=fileparts(mfilename('fullpath'));C=jsondecode(fileread(fullfile(here,'audit.json')));if ~iscell(C),C=num2cell(C);end
S=load(fullfile(here,'pi_design.mat'),'designs');D=S.designs;
base=fullfile(fileparts(here),'48_72_120_C220_16_8');
for n=1:5,C{n}.cfg=readConfig(fullfile(base,C{n}.cfg.codeRel));end
raw=jsondecode(fileread(fullfile(base,'config','switch_cases.json')));if ~iscell(raw),raw=num2cell(raw);end
for n=1:numel(raw)
 cfg=readConfig(fullfile(base,raw{n}.codeRel));C{end+1}=struct('cfg',cfg,'initialization',struct('warmup',cfg.warmupTime));
end
for k=indices
 c=C{k};cfg=c.cfg;p=[];if k<=5,p=D{k};end;folder=fullfile(here,'results',cfg.id);if ~isfolder(folder),mkdir(folder);end
 for j=1:numel(controllers)
  kind=controllers{j};file=fullfile(folder,[kind '.mat']);
  if isfile(file),fprintf('PI_CASE_CACHED %s %s\n',cfg.id,kind);continue;end
  model=['CMP_' cfg.id '_' kind];dest=fullfile(folder,[model '.slx']);
  if bdIsLoaded(model),close_system(model,0);end
  src=fullfile(cfg.caseDir,'circuit',['TPC_' cfg.id '_CLOSED.slx']);
  if k>5,src=fullfile(cfg.caseDir,'circuit',['TPC_SWITCH_' strrep(cfg.id,'_EXTRA','') '.slx']);end
  source=load_system(src);save_system(source,dest);close_system(source,0);load_system(dest);
  if strcmp(kind,'PI')
   if k<=5,installPI(model,p,c.initialization.warmup);
   else
    p=cell(numel(cfg.mapping),1);
    if startsWith(cfg.id,'DISO'),first='DISO';elseif startsWith(cfg.id,'SIDO'),first='SIDO';else,first='SISO_VS_VO';end
    for n=1:numel(cfg.mapping)
     map=cfg.mapping(n);q=find(cellfun(@(d)strcmp(d.id,map.mode),D),1);pn=D{q};M=C{q}.models;if iscell(M),M=vertcat(M{:});end
     mm=find([M.Rload]==cfg.Rload,1);pn.uBase=M(mm).anchor.u(:);pn.iBase=M(mm).anchor.x(1);p{n}=pn;
     old=find_system(model,'RegExp','on','Name',sprintf('^TPC_NN_%d$',n));assert(numel(old)==1);
     pi_install_switch(model,old{1},pn,c.initialization.warmup,map.head,cfg.events,strcmp(first,map.mode));
    end
   end
  end
  set_param(model,'SimulationMode','normal','ReturnWorkspaceOutputs','on');
  set_param(model,'FastRestart','off');save_system(model,dest);tpc_assert_topology(src,dest);
  fprintf('PI_CASE_START %s %s\n',cfg.id,kind);tic;out=sim(model);elapsed=toc;
  z=out.get('TPC_trace');t=z.Time(:);a=squeeze(z.Data);if size(a,1)~=numel(t),a=a';end
  assert(all(isfinite(a),'all'),'Non-finite trace.');
  warm=c.initialization.warmup;startupPeak=max(abs(a(t<warm,1)));mask=t>=warm-1e-10;t=t(mask)-warm;a=a(mask,:);
  [tc,ac]=cycleMeans(t,a,cfg.Ts);report=measure(tc,ac,t,a,cfg);report.controller=kind;report.id=cfg.id;report.elapsedSeconds=elapsed;report.initializationSeconds=warm;report.initializationPeakA=startupPeak;
  % Preserve every full PWM cycle for event zoom, averages for the complete run.
  keep=false(size(t));for te=cfg.events(:)',keep=keep|(t>=te-.0005&t<=te+.003);end
  rawT=t(keep);rawA=a(keep,:);
  save(file,'tc','ac','rawT','rawA','report','cfg','p','-v7.3');
  fid=fopen(fullfile(folder,[kind '.json']),'w');fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);
  close_system(model,0);fprintf('PI_CASE_COMPLETE %s %s mean=%g eventPeak=%g elapsed=%g\n',cfg.id,kind,report.finalMeanV,max([report.events.peakDepartureV]),elapsed);
 end
end
end
function cfg=readConfig(folder)
run(fullfile(folder,'parameters.m'));
end
function installPI(mdl,p,warm)
blocks=find_system(mdl,'RegExp','on','Name','^TPC_NN$');assert(numel(blocks)==1,'Expected one multi-output NN.');old=blocks{1};parent=get_param(old,'Parent');ph=get_param(old,'PortHandles');
src=sourcePort(get_param(ph.Inport(1),'Line'));line=get_param(ph.Outport(1),'Line');dst=get_param(line,'DstPortHandle');dst=dst(dst>0);pos=get_param(old,'Position');delete_line(line);delete_block(old);
name=[parent '/PI_Cascade'];add_block('simulink/User-Defined Functions/MATLAB Function',name,'Position',pos);
clock=[parent '/PI_Clock'];add_block('simulink/Sources/Digital Clock',clock,'SampleTime',num2str(p.Ts,17),'Position',[pos(1)-150 pos(2)+120 pos(1)-100 pos(2)+150]);
rt=sfroot;chart=rt.find('-isa','Stateflow.EMChart','Path',name);
body=fileread(fullfile(fileparts(mfilename('fullpath')),'pi_controller_template.txt'));
body=strrep(body,'@PARAMETERS@',sprintf('Ts=%s;kpI=%s;kiI=%s;kpV=%s;kiV=%s;dir=%s;ub=%s;lo=%s;hi=%s;ib=%s;imin=%s;imax=%s;warm=%s;',...
 num2str(p.Ts,17),num2str(p.KpI,17),num2str(p.KiI,17),num2str(p.KpV,17),num2str(p.KiV,17),mat2str(p.direction,17),mat2str(p.uBase,17),mat2str(p.uMin,17),mat2str(p.uMax,17),num2str(p.iBase,17),num2str(p.currentMin,17),num2str(p.currentMax,17),num2str(warm,17)));
chart.Script=body;np=get_param(name,'PortHandles');cp=get_param(clock,'PortHandles');
connectPort(parent,src,np.Inport(1));connectPort(parent,cp.Outport(1),np.Inport(2));
for d=unique(dst(:))',connectPort(parent,np.Outport(1),d);end
set_param(parent,'AttributesFormatString','Discrete voltage PI -> current PI -> identical duty limits');
end
function connectPort(parent,src,dst)
lh=get_param(dst,'Line');if lh>0
 old=sourcePort(lh);if old==src,return;end
 if old>0,delete_line(parent,old,dst);else,delete_line(lh);end
end
add_line(parent,src,dst,'autorouting','on');
end
function sp=sourcePort(line)
sp=get_param(line,'SrcPortHandle');while sp<0,parent=get_param(line,'LineParent');if isempty(parent)||parent<0,return;end;line=parent;sp=get_param(line,'SrcPortHandle');end
end
function [tc,ac]=cycleMeans(t,a,Ts)
g=floor((t+Ts*1e-7)/Ts);[ids,~,q]=unique(g);n=accumarray(q,1);ok=n>=.99*Ts/1e-7;tc=(ids+.5)*Ts;tc=tc(ok);ac=zeros(sum(ok),size(a,2));
for j=1:size(a,2),v=accumarray(q,a(:,j))./n;ac(:,j)=v(ok);end
end
function r=measure(tc,ac,t,a,cfg)
r=struct();r.finalMeanV=mean(ac(tc>=tc(end)-.001,2));r.finalErrorPct=100*abs(r.finalMeanV/cfg.Vref-1);r.feedbackPeakCurrentA=max(abs(a(:,1)));r.feedbackMinimumV=min(a(:,2));r.feedbackMaximumV=max(a(:,2));r.recoveryBandV=.1;
edges=[0;cfg.events(:);tc(end)+cfg.Ts/2];P=cell(numel(edges)-1,1);
for k=1:numel(P)
 w=tc>=max(edges(k)+.001,edges(k+1)-.001)&tc<edges(k+1);v=mean(ac(w,2));P{k}=struct('window',[max(edges(k)+.001,edges(k+1)-.001),edges(k+1)],'meanV',v,'errorPct',100*abs(v/cfg.Vref-1),'meanCurrentA',mean(ac(w,1)));
end
r.plateaus=vertcat(P{:});r.maximumPlateauErrorPct=max([r.plateaus.errorPct]);E=cell(numel(cfg.events),1);
for k=1:numel(E)
 te=cfg.events(k);stop=min(te+.003,edges(k+2)-.0005);pre=tc>=te-.0005&tc<te;post=tc>=stop-.0005&tc<stop;idx=find(tc>=te&tc<=stop);pm=mean(ac(pre,2));qm=mean(ac(post,2));bad=idx(abs(ac(idx,2)-qm)>.1);recovery=0;
 if ~isempty(bad),recovery=NaN;if bad(end)<idx(end),recovery=(tc(bad(end)+1)-te)*1e6;end;end
 E{k}=struct('time',te,'preMeanV',pm,'postMeanV',qm,'peakDepartureV',max(abs(ac(idx,2)-pm)),'recoveryUs',recovery,'IAE_Vs',sum(abs(ac(idx,2)-cfg.Vref))*cfg.Ts);
end
r.events=vertcat(E{:});
end
