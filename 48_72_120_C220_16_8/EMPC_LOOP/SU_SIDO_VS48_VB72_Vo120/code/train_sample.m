function train_sample()
% 本文件直接包含本步骤的计算过程；参数统一在 parameters.m 修改。
codeDir = fileparts(mfilename('fullpath'));
run(fullfile(codeDir, 'parameters.m'));

% Local state-domain labels for scalar or independently driven MIMO modes.
%% 读取本工况EMPC
S=load(fullfile(cfg.codeDir,'models','EMPC_48_72_120.mat'),'teachers');M=load(fullfile(cfg.codeDir,'models','identified_model.mat'),'models');
addpath(fullfile(cfg.codeDir,'generated'),'-begin');rng(1726120);pools={};holdout=[];
anchors=cellfun(@(q)q.steadyAnchor.x(1),M.models);igrid=0:.2:cfg.currentMax;
for x=anchors(:)',igrid=[igrid,max(0,x-.6):.04:min(cfg.currentMax,x+.6)];end
igrid=unique(round(igrid*1e8)/1e8);
vgrid=unique(round([cfg.Vref-5:.05:cfg.Vref+5,cfg.Vref-.5:.005:cfg.Vref+.5]*1e8)/1e8);
%% 状态网格查询与标签生成
for k=1:numel(S.teachers)
 T=S.teachers{k};f=str2func(T.functionName);[ii,vv]=ndgrid(igrid,vgrid);points=[ii(:),vv(:)];base=nan(size(points,1),4+cfg.nu);
 for j=1:size(points,1)
  [u,r]=f(points(j,:)');if r>0&&all(isfinite(u))&&all(u>=-1e-7)&&all(u<=cfg.dutyMax(:)+1e-7),base(j,:)=[points(j,:),points(j,2)/T.Rload,T.Vref,u(:)'];end
 end
 base=base(all(isfinite(base),2),:);middle=find(any(base(:,5:end)>.005&base(:,5:end)<cfg.dutyMax(:)'-.005,2));sat=setdiff((1:size(base,1))',middle);
 if numel(middle)>18000,middle=middle(randperm(numel(middle),18000));end
 if numel(sat)>4000,sat=sat(randperm(numel(sat),4000));end
 base=base(sort([middle;sat]),:);aug=repmat(base,3,1);n=size(base,1);
 aug(:,3)=aug(:,3)+[zeros(n,1);-.025*ones(n,1);.025*ones(n,1)];pools{k}=aug;
 h=nan(3000,4+cfg.nu);states=[cfg.currentMax*rand(3000,1),cfg.Vref-5+10*rand(3000,1)];
 for j=1:3000
  [u,r]=f(states(j,:)');if r>0&&all(isfinite(u)),h(j,:)=[states(j,:),states(j,2)/T.Rload+.05*(rand-.5),T.Vref,u(:)'];end
 end
 holdout=[holdout;h(all(isfinite(h),2),:)];fprintf('LOCAL_LABELS %s R=%g retained=%d augmented=%d\n',cfg.id,T.Rload,n,size(aug,1));
end
%% 保存训练与独立验证数据
changeR1=vertcat(pools{:});save(fullfile(cfg.codeDir,'data','changeR1.mat'),'changeR1','cfg','-v7.3');
save(fullfile(cfg.codeDir,'data','offgrid_holdout.mat'),'holdout','cfg','-v7.3');save(fullfile(cfg.codeDir,'data','shu_all.mat'),'pools','cfg','-v7.3');
end
