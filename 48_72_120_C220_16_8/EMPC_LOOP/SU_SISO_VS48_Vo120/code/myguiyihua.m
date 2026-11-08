function myguiyihua()
% 本文件直接包含本步骤的计算过程；参数统一在 parameters.m 修改。
codeDir = fileparts(mfilename('fullpath'));
cfg = tpc_load_case(codeDir); % 显式返回参数，兼容嵌套函数的静态工作区

% Two ReLU hidden layers. MSE and chain-rule gradients; no momentum or control fallback.
%% 读取训练集与划分样本
S=load(fullfile(cfg.codeDir,'data','changeR1.mat'),'changeR1');P=S.changeR1;X=P(:,1:4)';Y=P(:,5:end)';nu=cfg.nu;
splitKey=X';
if isfield(cfg,'groupLoadFamilies')&&cfg.groupLoadFamilies
    r=splitKey(:,2)./max(splitKey(:,3),1e-9);[~,family]=min(abs(r-cfg.Rloads(:)'),[],2);splitKey(:,3)=family;
end
[~,~,group]=unique(round(splitKey*1e8),'rows');rng(42);order=randperm(max(group));n=numel(order);a=floor(.7*n);b=floor(.15*n);
trainIdx=find(ismember(group,order(1:a)));valIdx=find(ismember(group,order(a+1:a+b)));testIdx=find(ismember(group,order(a+b+1:end)));
%% 输入归一化
xmin=min(X(:,trainIdx),[],2);xmax=max(X(:,trainIdx),[],2);gain=2./max(xmax-xmin,1e-12);shift=-1-gain.*xmin;constant=xmax-xmin<1e-12;gain(constant)=0;shift(constant)=0;Z=gain.*X+shift;
Xt=Z(:,trainIdx);T=Y(:,trainIdx);Xv=Z(:,valIdx);Tv=Y(:,valIdx);
weight=1+4*(X(1,:)<=20&abs(X(2,:)-X(4,:))<=2);wt=weight(trainIdx);wv=weight(valIdx);
assert(numel(cfg.hiddenSizes)==2,'This implementation requires exactly two hidden layers.');
h1=cfg.hiddenSizes(1);h2=cfg.hiddenSizes(2);
assert(h1>=2*nu && h2>=nu,'Hidden layers are too small for the configured output count.');
%% 初始化两层ReLU网络
W1=.2*randn(h1,4);b1=.2*randn(h1,1);W2=.2*randn(h2,h1);b2=.2*randn(h2,1);W3=zeros(nu,h2);b3=zeros(nu,1);
for out=1:nu
    mid=T(out,:)>.02&T(out,:)<cfg.dutyMax(out)-.02;
    if sum(mid)>10
        regressors=[Xt(:,mid);ones(1,sum(mid))];active=[~constant;true];coef=zeros(5,1);
        coef(active)=regressors(active,:)'\T(out,mid)';s=max(1,norm(coef));j=2*out-1;
        W1(j:j+1,:)=repmat(coef(1:4)'/s,2,1);b1(j:j+1)=[coef(5);coef(5)-cfg.dutyMax(out)]/s;
        W2(out,:)=0;W2(out,j:j+1)=[s -s];b2(out)=0;W3(out,out)=1;
    end
end
sum1=zeros(h1,1);sum2=zeros(h2,1);
for first=1:4096:size(Xt,2)
    last=min(first+4095,size(Xt,2));aa1=max(0,W1*Xt(:,first:last)+b1);aa2=max(0,W2*aa1+b2);
    sum1=sum1+sum(aa1.^2,2);sum2=sum2+sum(aa2.^2,2);
end
d1=1./max(1,sqrt(sum(W2.^2,1)))';d2=1./max(1,sqrt(sum1/size(Xt,2)))';d3=1./max(1,sqrt(sum2/size(Xt,2)))';
clear aa1 aa2
base=pack(W1,b1,W2,b2,W3,b3);D=pack(repmat(d1,1,4),d1,repmat(d2,h2,1),ones(h2,1),repmat(d3,nu,1),ones(nu,1));
z=zeros(size(base));rmsG=zeros(size(base));bestZ=z;bestVal=inf;bestEpoch=0;patience=0;history=[];rate=.0007;stop='maximum_updates';goal=1e-8;nt=size(T,2);
maxUpdates=50000;if isfield(cfg,'maxUpdates'),maxUpdates=cfg.maxUpdates;end
minRate=1e-5;decay=isfield(cfg,'learningRateDecay')&&cfg.learningRateDecay;if decay,minRate=1e-7;end
%% 前向传播、反向传播与验证
for step=1:maxUpdates
    if decay,rate=min(rate,.0007*10^(-floor((step-1)/15000)));end
    idx=randperm(nt,min(512,nt));N=unpack(base+D.*z);xb=Xt(:,idx);tb=T(:,idx);ww=wt(idx);
    z1=N.W1*xb+N.b1;hh1=max(0,z1);z2=N.W2*hh1+N.b2;hh2=max(0,z2);e=N.W3*hh2+N.b3-tb;
    dy=2*e.*ww/sum(ww);g3=dy*hh2';gb3=sum(dy,2);dz2=(N.W3'*dy).*(z2>0);g2=dz2*hh1';gb2=sum(dz2,2);dz1=(N.W2'*dz2).*(z1>0);g1=dz1*xb';gb1=sum(dz1,2);
    g=D.*pack(g1,gb1,g2,gb2,g3,gb3);rmsG=.99*rmsG+.01*g.^2;z=z-rate*g./(sqrt(rmsG)+1e-8);
    if mod(step,500)==0||step==1
        N=unpack(base+D.*z);pt=forward(N,Xt);pv=forward(N,Xv);trainMSE=mean(sum((pt-T).^2,1));valMSE=mean(sum((pv-Tv).^2,1));valObjective=sum(sum((pv-Tv).^2,1).*wv)/sum(wv);
        assert(isfinite(trainMSE)&&isfinite(valMSE));history(end+1,:)=[step,trainMSE,valMSE,valObjective,rate]; %#ok<AGROW>
        if valObjective<bestVal-1e-10,bestVal=valObjective;bestZ=z;bestEpoch=step;patience=0;else,patience=patience+1;end
        fprintf('DEEP_RELU %s update=%d trainMSE=%.9g valMSE=%.9g weightedVal=%.9g\n',cfg.id,step,trainMSE,valMSE,valObjective);
        if trainMSE<=goal,stop='goal_reached';break;end
        if patience>=10,rate=max(minRate,rate*.5);end
        if patience>=40,stop='validation_early_stop';break;end
    end
end
%% 选取验证最优网络
net=unpack(base+D.*bestZ);net.inputGain=gain;net.inputShift=shift;net.activation='ReLU';net.outputActivation='linear';net.training='MSE + chain-rule backpropagation; minibatch gradient descent with positive RMS-adaptive per-weight rates, no momentum';
net.parameterInitialization='Trainable affine-band ReLU pairs and random remaining weights; no runtime analytic duty or controller fallback';
%% 独立测试与结果保存
testPrediction=forward(net,Z(:,testIdx));testMetrics=metrics(testPrediction,Y(:,testIdx));H=load(fullfile(cfg.codeDir,'data','offgrid_holdout.mat'),'holdout');hx=H.holdout(:,1:4)';hy=H.holdout(:,5:end)';holdoutPrediction=forward(net,gain.*hx+shift);freshMetrics=metrics(holdoutPrediction,hy);
finalTrainingMSE=mean(sum((forward(net,Xt)-T).^2,1));training=struct('stop',stop,'updates',step,'bestUpdate',bestEpoch,'trainingMSE',finalTrainingMSE,'goal',goal,'test',testMetrics,'freshOffgrid',freshMetrics,'inputCount',4,'hiddenCounts',[h1 h2],'independentDutyOutputs',nu,'lossWeighting','Weight 5 for iL<=20A and |Vo-Vref|<=2V; all other samples retain weight 1. Test metrics are unweighted.');
save(fullfile(cfg.codeDir,'models','net_48_72_120.mat'),'net','training','history','trainIdx','valIdx','testIdx','testPrediction','holdoutPrediction','cfg','-v7.3');fid=fopen(fullfile(cfg.codeDir,'results','NN_validation.json'),'w');fprintf(fid,'%s',jsonencode(training,PrettyPrint=true));fclose(fid);
fig=figure('Visible','off');tiledlayout(1,2);nexttile;semilogy(history(:,1),history(:,2:3));legend('train','validation');grid on;nexttile;scatter(hy(:),holdoutPrediction(:),4,'filled');hold on;plot([0 1],[0 1],'r--');xlabel('EMPC label');ylabel('ReLU NN');grid on;exportgraphics(fig,fullfile(cfg.codeDir,'results','NN_fit.png'),'Resolution',180);close(fig);disp(training);fprintf('DEEP_RELU_COMPLETE %s\n',cfg.id);
tpc_show_figures(codeDir,'network');
    function N=unpack(v)
        j=0;N.W1=reshape(v(j+1:j+4*h1),h1,4);j=j+4*h1;N.b1=v(j+1:j+h1);j=j+h1;N.W2=reshape(v(j+1:j+h1*h2),h2,h1);j=j+h1*h2;N.b2=v(j+1:j+h2);j=j+h2;N.W3=reshape(v(j+1:j+nu*h2),nu,h2);j=j+nu*h2;N.b3=v(j+1:end);
    end
end
function v=pack(varargin),v=[];for k=1:nargin,v=[v;varargin{k}(:)];end;end
function y=forward(N,x)
y=zeros(size(N.W3,1),size(x,2));
for first=1:4096:size(x,2)
    last=min(first+4095,size(x,2));v=x(:,first:last);
    y(:,first:last)=N.W3*max(0,N.W2*max(0,N.W1*v+N.b1)+N.b2)+N.b3;
end
end
function m=metrics(y,t),e=y-t;m=struct('count',size(y,2),'RMSE',sqrt(mean(e.^2,2)),'MAE',mean(abs(e),2),'maxAbs',max(abs(e),[],2),'rawDutyMin',min(y,[],2),'rawDutyMax',max(y,[],2));end
