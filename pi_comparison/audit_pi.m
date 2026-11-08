function audit_pi()
here=fileparts(mfilename('fullpath')); root=fileparts(here); base=fullfile(root,'48_72_120_C220_16_8');
diary(fullfile(here,'audit.log')); cleanup=onCleanup(@()diary('off'));
fprintf('MATLAB %s\n',version); fprintf('CONTROL_TOOLBOX %d\n',license('test','Control_Toolbox'));
raw=jsondecode(fileread(fullfile(base,'config','target_cases.json')));if ~iscell(raw),raw=num2cell(raw);end
result=cell(numel(raw),1);
for k=1:numel(raw)
 [cfg,init]=readcfg(fullfile(base,raw{k}.codeRel));
 S=load(fullfile(cfg.codeDir,'models','identified_model.mat'),'models');
 item=struct('id',cfg.id,'cfg',cfg,'initialization',init,'models',[],'blocks',[]);
 mm=cell(numel(S.models),1);
 for j=1:numel(S.models)
  q=S.models{j};mm{j}=struct('Rload',q.Rload,'A',q.A,'B',q.B,'f',q.f,'anchor',q.steadyAnchor);
 end
 item.models=mm;
 src=fullfile(cfg.caseDir,'circuit',['TPC_' cfg.id '_CLOSED.slx']);
 h=load_system(src);original=get_param(h,'Name'); % inspect the saved baseline without saving it
 item.stopTime=get_param(original,'StopTime');
 names=find_system(original,'SearchDepth',1,'Type','Block');
 for b=1:numel(names)
  n=get_param(names{b},'Name');
  if startsWith(n,'TPC_')
   item.blocks(end+1).name=n;item.blocks(end).type=get_param(names{b},'BlockType');
  end
 end
 close_system(original,0);result{k}=item;fprintf('AUDIT %s\n',cfg.id);
end
fid=fopen(fullfile(here,'audit.json'),'w');fprintf(fid,'%s',jsonencode(result,PrettyPrint=true));fclose(fid);
end
function [cfg,initialization]=readcfg(folder)
run(fullfile(folder,'parameters.m'));
end
