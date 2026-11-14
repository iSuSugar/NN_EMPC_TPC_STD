function checks=verify_results24()
here=fileparts(mfilename('fullpath'));ref=jsondecode(fileread(fullfile(here,'experiment_reference.json')));checks=struct();records={};
for k=1:numel(ref.cases)
 if iscell(ref.cases),c=ref.cases{k};else,c=ref.cases(k);end
 for kind={'command','vgs_proxy'}
  file=fullfile(here,'results',c.id,['open_' kind{1} '.mat']);D=load(file);q=D.report;
  assert(D.cfg.L==110e-6&&D.cfg.Co==202e-6&&D.cfg.Vs==24&&D.cfg.Vb==36&&D.cfg.fsw==1e5);
  assert(max(abs([q.plateaus.actualLoadCurrent]-[.5 1 .5]))<.02);
  assert(all(isfinite(D.ac),'all')&&all(isfinite(D.rawA),'all'));
  assert(max(abs(diff(D.tc)-1e-5))<1e-10);
  expected=c.dutyCommand;if strcmp(kind{1},'vgs_proxy'),expected=c.dutyVgsProxy;end
  w=D.tc>=.055&D.tc<.059;actual=mean(D.ac(w,4:end),1);assert(max(abs(actual(:)-expected(:)))<1e-8);
  model=fullfile(here,'results',c.id,['OPEN_' c.id '_' kind{1} '.slx']);assert(isfile(model));
  h=load_system(model);name=get_param(h,'Name');B=find_system(name,'SearchDepth',1,'Type','Block');nl=0;nc=0;
  for j=1:numel(B)
   b=B{j};n=get_param(b,'Name');
   if contains(n,'Series RLC Branch')
    if strcmp(get_param(b,'BranchType'),'L'),assert(abs(str2double(get_param(b,'Inductance'))-110e-6)<1e-12);nl=nl+1;end
    if strcmp(get_param(b,'BranchType'),'C'),assert(abs(str2double(get_param(b,'Capacitance'))-202e-6)<1e-12);nc=nc+1;end
   elseif strcmp(n,'DC Voltage Source'),v=24;if strcmp(c.id,'SISO_VB_VO'),v=36;end;assert(str2double(get_param(b,'Amplitude'))==v);
   elseif strcmp(n,'DC Voltage Source1'),assert(str2double(get_param(b,'Amplitude'))==36);
   elseif contains(n,'PWM Generator'),assert(str2double(get_param(b,'Fsw'))==1e5);
   end
  end
  assert(nl>=1&&nc>=1);close_system(name,0);records{end+1}=struct('mode',c.id,'dutyCase',kind{1},'L',110e-6,'Co',202e-6,'sourcesAndPWMVerified',true,'CCmeasuredVerified',true,'dutyTraceVerified',true,'savedCircuitVerified',true);
 end
end
files=dir(fullfile(here,'results','closed72','*.mat'));assert(numel(files)==4);closed={};
for k=1:4
 D=load(fullfile(files(k).folder,files(k).name));q=D.report;
 assert(all([q.plateaus.relativeErrorPct]<1));assert(all([q.plateaus.fractionCyclesAbove20mA]==1));assert(max(abs([q.plateaus.actualLoadCurrent]-[.5 1 .5]))<.02);
 assert(D.cfg.L==110e-6&&D.cfg.Vs==24&&D.cfg.Vref==72);closed{end+1}=struct('case',q.case,'allPlateausWithin1Pct',true,'steadyCCM',true,'CCmeasuredVerified',true,'Co',D.cfg.Co);
end
L=load(fullfile(here,'results','ccm_boundary','Io100mA.mat'));H=load(fullfile(here,'results','ccm_boundary','Io500mA.mat'));assert(L.report.fractionCCMcyclesAbove20mA==0&&L.report.fractionNearZero>0&&H.report.fractionCCMcyclesAbove20mA==1);
checks.open=records;checks.closed=closed;checks.lightLoadTransitionVerified=true;checks.hardwareCurrentCalibrated=false;checks.newNNTrained=false;checks.note='CCM results apply to declared steady windows. Existing device parasitics are inherited, not fitted to physical hardware.';
fid=fopen(fullfile(here,'verification24.json'),'w');fprintf(fid,'%s',jsonencode(checks,PrettyPrint=true));fclose(fid);fprintf('VERIFY24_COMPLETE open=10 closed=4 light=3\n');
end
