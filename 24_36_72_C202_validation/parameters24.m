function cfg=parameters24(id)
here=fileparts(mfilename('fullpath'));base=fullfile(fileparts(here),'48_72_120_C220_16_8');
raw=jsondecode(fileread(fullfile(base,'config','target_cases.json')));if ~iscell(raw),raw=num2cell(raw);end
k=find(cellfun(@(x)strcmp(x.id,id),raw),1);assert(~isempty(k));cfg=readOriginal(fullfile(base,raw{k}.codeRel));
cfg.Vs=24;cfg.Vb=36;cfg.Vref=72;if strcmp(id,'SISO_VS_VB'),cfg.Vref=36;end
cfg.L=110e-6;cfg.Co=202e-6;cfg.fsw=1e5;cfg.Ts=1e-5;
cfg.caseDir=fullfile(here,'cases',id);cfg.codeDir=fullfile(cfg.caseDir,'code');cfg.events=[.06;.08];
folder=fullfile(cfg.caseDir,'circuit','template');if ~isfolder(folder),mkdir(folder);end
[~,name,ext]=fileparts(cfg.source);local=fullfile(folder,[name ext]);if ~isfile(local),copyfile(cfg.source,local);end;cfg.source=local;
end
function cfg=readOriginal(folder)
run(fullfile(folder,'parameters.m'));
end
