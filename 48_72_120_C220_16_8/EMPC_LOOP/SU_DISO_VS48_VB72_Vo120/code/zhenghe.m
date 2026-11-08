function zhenghe()
% 本文件直接包含本步骤的计算过程；参数统一在 parameters.m 修改。
codeDir = fileparts(mfilename('fullpath'));
run(fullfile(codeDir, 'parameters.m'));

%% 合并各负载样本，形成网络训练数据
S=load(fullfile(codeDir,'data','shu_all.mat'),'pools');
changeR1=vertcat(S.pools{:});
save(fullfile(codeDir,'data','changeR1.mat'),'changeR1','cfg','-v7.3');
fprintf('训练样本数：%d\n',size(changeR1,1));
end
