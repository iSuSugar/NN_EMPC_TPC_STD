function run_all_modes(stage)
% Batch the original-style local entry files; no tools setup is required.
if nargin<1,stage='all';end
root=fileparts(mfilename('fullpath'));
aliases=struct('identify','model_calculate','empc','EMPC1','sample','train_sample',...
 'merge','zhenghe','train','myguiyihua','closed','run_closed_loop','plots','show_results','all','run_all');
assert(isfield(aliases,stage),'Unknown stage %s',stage);entry=aliases.(stage);
raw=jsondecode(fileread(fullfile(root,'config','target_cases.json')));if ~iscell(raw),raw=num2cell(raw);end
if any(strcmp(stage,{'all','closed','plots'}))
 extra=jsondecode(fileread(fullfile(root,'config','switch_cases.json')));if ~iscell(extra),extra=num2cell(extra);end
 raw=[raw(:);extra(:)];
end
if ~isfolder(fullfile(root,'results')),mkdir(fullfile(root,'results'));end
old=pwd;cleanup=onCleanup(@()cd(old));status=struct('id',{},'stage',{},'completed',{},'error',{},'finishedAt',{});
for k=1:numel(raw)
 c=raw{k};codeDir=fullfile(root,c.codeRel);ok=true;message='';
 try
  cd(codeDir);feval(entry);
 catch e
  ok=false;message=getReport(e,'extended','hyperlinks','off');fprintf(2,'%s\n',message);
 end
 status(end+1)=struct('id',c.id,'stage',stage,'completed',ok,'error',message,'finishedAt',char(datetime('now'))); %#ok<AGROW>
 fid=fopen(fullfile(root,'results','run_status.json'),'w');fprintf(fid,'%s',jsonencode(status,PrettyPrint=true));fclose(fid);
end
fprintf('Pipeline finished: %d/%d execution stages completed. See results/run_status.json.\n',sum([status.completed]),numel(status));
end
