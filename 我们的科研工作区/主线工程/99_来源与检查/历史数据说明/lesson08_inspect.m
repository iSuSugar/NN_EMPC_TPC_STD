% Read saved source copies, export only a small teaching sample.
dest=fileparts(mfilename('fullpath'));cd(dest);diary('lesson08_inspect.txt');
base=fullfile(dest,'..','03_仿真复现','第01轮_SISO_VS48_Vo200','模型与算法','代码');
s=load(fullfile(base,'model_train.mat'),'model_train','iL','Vo');
fprintf('MODEL_TRAIN rows=%d\n',size(s.model_train,1));disp(s.model_train(1:6,:));
writetable(array2table(s.model_train(1:6,:),'VariableNames',{'iL_k','Vo_k','d_k','iL_next','Vo_next'}),'lesson08_model_rows.csv');
for name={'iL','Vo'}
 n=name{1};if isfield(s,n),a=s.(n);fprintf('%s size=%s\n',n,mat2str(size(a)));if isnumeric(a)&&size(a,2)==2,dt=diff(a(:,1));fprintf('dt min %.12g max %.12g median %.12g\n',min(dt),max(dt),median(dt));end;end
end
X=s.model_train(:,1:3);Y=s.model_train(:,4:5);theta=X\Y;
fprintf('OLS theta\n');disp(theta);writematrix(theta,'lesson08_theta.csv');
t=load(fullfile(base,'shu150.mat'),'shu150');fprintf('SHU150 rows=%d\n',size(t.shu150,1));
ids=unique(round(linspace(1,size(t.shu150,1),6)));disp(t.shu150(ids,:));
writetable(array2table(t.shu150(ids,:),'VariableNames',{'iL','Vo','feature','Vref','d_label'}),'lesson08_label_rows.csv');
fprintf('COMPLETE\n');diary off;
