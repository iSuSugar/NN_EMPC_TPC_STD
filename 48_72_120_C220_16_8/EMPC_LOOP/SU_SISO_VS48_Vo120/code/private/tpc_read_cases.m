function C=tpc_read_cases(file)
% JSON configurations have mode-specific fields and may decode to cells.
raw=jsondecode(fileread(file));
if ~iscell(raw),raw=num2cell(raw);end
root=fileparts(fileparts(file));
for k=1:numel(raw)
 r=raw{k};
 if isfield(r,'codeRel')&&~isempty(r.codeRel),r.codeDir=fullfile(root,r.codeRel);r.caseDir=fileparts(r.codeDir);end
 configFile=fullfile(r.codeDir,'case_config.json');if ~isfile(configFile),configFile=fullfile(r.codeDir,'switch_config.json');end
 if isfile(fullfile(r.codeDir,'parameters.m'))
  local=tpc_load_case(r.codeDir);f=fieldnames(local);for j=1:numel(f),if ~any(strcmp(f{j},{'codeDir','caseDir'})),r.(f{j})=local.(f{j});end;end
 end
 raw{k}=r;
end
if iscell(raw)
 fields={};for k=1:numel(raw),fields=union(fields,fieldnames(raw{k}));end
 for k=1:numel(raw),missing=setdiff(fields,fieldnames(raw{k}));for j=1:numel(missing),raw{k}.(missing{j})=[];end;raw{k}=orderfields(raw{k});end
 C=vertcat(raw{:});
else,C=raw;end
for k=1:numel(C)
 if isfield(C,'codeRel')&&~isempty(C(k).codeRel),C(k).codeDir=fullfile(root,C(k).codeRel);C(k).caseDir=fileparts(C(k).codeDir);end
end
end
