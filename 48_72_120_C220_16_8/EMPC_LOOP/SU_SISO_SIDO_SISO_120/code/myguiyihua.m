function myguiyihua()
% 本文件直接包含本步骤的计算过程；参数统一在 parameters.m 修改。
codeDir = fileparts(mfilename('fullpath'));
run(fullfile(codeDir, 'parameters.m'));

%% 切换复用组成模式；缺少产物时运行对应独立工况步骤
root=tpc_project_root();C=tpc_read_cases(fullfile(root,'config','target_cases.json'));
needed=unique({cfg.mapping.mode});
for k=1:numel(needed)
 j=find(strcmp({C.id},needed{k}),1);assert(~isempty(j));
 if ~isfile(fullfile(C(j).codeDir,'models/net_48_72_120.mat'))
  tpc_run_mode_entry(C(j).codeDir,'myguiyihua');
 else
  fprintf('复用 %s 的 myguiyihua 产物\n',needed{k});
 end
end
end
