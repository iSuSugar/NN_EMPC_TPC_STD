function files=organize_circuit(showModel)
% 整理本工况已经保存的电路，不重训、不重新生成电路。
% organize_circuit 显示闭环电路；organize_circuit(false) 只整理保存。
if nargin<1,showModel=true;end
codeDir=fileparts(mfilename('fullpath'));circuitDir=fullfile(fileparts(codeDir),'circuit');
cfg=tpc_load_case(codeDir);
files=dir(fullfile(circuitDir,'*.slx'));
for k=1:numel(files)
 path=fullfile(files(k).folder,files(k).name);[~,mdl]=fileparts(path);
 assert(~bdIsLoaded(mdl),'Please close %s before organizing its saved file.',mdl);
 load_system(path);tpc_readable_layout(mdl);save_system(mdl);close_system(mdl,0);
 tpc_assert_topology(cfg.source,path);
end
if showModel
 names={files.name};j=find(contains(names,'CLOSED')|contains(names,'SWITCH'),1);
 if ~isempty(j),open_system(fullfile(files(j).folder,files(j).name));end
end
end
