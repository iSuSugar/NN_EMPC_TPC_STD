function result=tpc_verify_candidate_nn(cfg,trajectory,tag)
% Compare the saved network against exact EMPC at actual electrical samples.
P=load(trajectory,'controllerLog');log=P.controllerLog;N=load(fullfile(cfg.codeDir,'models','net_48_72_120.mat'),'net');
if nargin<3,tag='NN_actual_trajectory';end
S=load(fullfile(cfg.codeDir,'models','EMPC_48_72_120.mat'),'teachers');addpath(fullfile(cfg.codeDir,'generated'),'-begin');
target=nan(size(log,1),cfg.nu);prediction=target;feasible=false(size(log,1),1);
for k=1:size(log,1)
 x=log(k,2:5)';r=x(2)/max(x(3),1e-9);[~,j]=min(cellfun(@(q)abs(q.Rload-r),S.teachers));
 f=str2func(S.teachers{j}.functionName);[u,region]=f(x(1:2));prediction(k,:)=tpc_nn_predict(N.net,x)';
 if region>0&&all(isfinite(u)),target(k,:)=u';feasible(k)=true;end
end
e=prediction(feasible,:)-target(feasible,:);result=struct('trajectory',trajectory,'totalPoints',size(log,1),'feasiblePoints',sum(feasible),...
 'RMSE',sqrt(mean(e.^2,1)),'maximumAbsoluteDutyError',max(abs(e),[],1),...
 'rawNetworkReplayRMSE',sqrt(mean((prediction-log(:,6:5+cfg.nu)).^2,1)),...
 'note','Actual circuit state queries; independent of random sample MSE. No idealized Io replacement or state clipping.');
save(fullfile(cfg.codeDir,'results',[tag '.mat']),'result','target','prediction','log','feasible');
fid=fopen(fullfile(cfg.codeDir,'results',[tag '.json']),'w');fprintf(fid,'%s',jsonencode(result,PrettyPrint=true));fclose(fid);disp(result);
end
