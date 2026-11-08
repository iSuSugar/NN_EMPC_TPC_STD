function train_sample()
% 本文件直接包含本步骤的计算过程；参数统一在 parameters.m 修改。
codeDir = fileparts(mfilename('fullpath'));
run(fullfile(codeDir, 'parameters.m'));

% Candidate operating domain only. Startup is external to this local NN.
%% 读取本工况EMPC
S=load(fullfile(cfg.codeDir,'models','EMPC_48_72_120.mat'),'teachers');
addpath(fullfile(cfg.codeDir,'generated'),'-begin');rng(1726120);pools={};holdout=[];
igrid=unique([0:.2:18,2.8:.04:3.8,7.4:.04:8.4]);
vgrid=unique(round([115:.05:125,119.5:.005:120.5]*1e8)/1e8);
%% 状态网格查询与标签生成
for k=1:numel(S.teachers)
 T=S.teachers{k};f=str2func(T.functionName);[ii,vv]=ndgrid(igrid,vgrid);points=[ii(:),vv(:)];base=nan(size(points,1),5);
 for j=1:size(points,1)
  [u,r]=f(points(j,:)');if r>0&&isfinite(u)&&u>=-1e-7&&u<=cfg.dutyMax+1e-7,base(j,:)=[points(j,:),points(j,2)/T.Rload,T.Vref,u];end
 end
 base=base(all(isfinite(base),2),:);middle=find(base(:,5)>.005&base(:,5)<cfg.dutyMax-.005);sat=find(base(:,5)<=.005|base(:,5)>=cfg.dutyMax-.005);
 if numel(middle)>18000,middle=middle(randperm(numel(middle),18000));end
 if numel(sat)>4000,sat=sat(randperm(numel(sat),4000));end
 base=base(sort([middle;sat]),:);aug=repmat(base,3,1);
 aug(:,3)=aug(:,3)+[zeros(size(base,1),1);-.025*ones(size(base,1),1);.025*ones(size(base,1),1)];pools{k}=aug;
 h=nan(3000,5);states=[18*rand(3000,1),115+10*rand(3000,1)];
 for j=1:3000
  [u,r]=f(states(j,:)');if r>0&&isfinite(u),h(j,:)=[states(j,:),states(j,2)/T.Rload+.05*(rand-.5),T.Vref,u];end
 end
 holdout=[holdout;h(all(isfinite(h),2),:)];fprintf('LOCAL_LABELS R=%g retained=%d augmented=%d\n',T.Rload,size(base,1),size(aug,1));
end
%% 保存训练与独立验证数据
changeR1=vertcat(pools{:});save(fullfile(cfg.codeDir,'data','changeR1.mat'),'changeR1','cfg','-v7.3');
save(fullfile(cfg.codeDir,'data','offgrid_holdout.mat'),'holdout','cfg','-v7.3');
save(fullfile(cfg.codeDir,'data','shu_all.mat'),'pools','cfg','-v7.3');
end
