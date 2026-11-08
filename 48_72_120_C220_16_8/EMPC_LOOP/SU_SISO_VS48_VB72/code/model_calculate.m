function [models,cfg]=model_calculate()
% 本文件直接包含本步骤的计算过程；参数统一在 parameters.m 修改。
codeDir = fileparts(mfilename('fullpath'));
run(fullfile(codeDir, 'parameters.m'));

%% 1. 本工况数据位置
caseId=cfg.id;active=codeDir;old=[];
dest=fullfile(codeDir,'data','prbs');if ~isfolder(dest),mkdir(dest);end

%% 2. 逐负载读取/采集数据，辨识并验证预测模型
models=cell(numel(cfg.Rloads),1);checks={};
for j=1:numel(cfg.Rloads)
    R=cfg.Rloads(j);rawFile=fullfile(dest,sprintf('raw_R%g.mat',R));
    if isfile(rawFile)
        S=load(rawFile,'t','a','anchor','center','cfg');
        physical={'id','Vs','Vb','Ts','fsw','L','Co','nu','Rloads','fixedDutyS1'};
        for key=physical
            name=key{1};if isfield(cfg,name)&&isfield(S.cfg,name),assert(isequal(cfg.(name),S.cfg.(name)),'Raw PRBS parameter %s differs; preserve this data and recollect into a new data folder.',name);end
        end
        t=S.t;a=S.a;anchor=S.anchor;center=S.center;
    else
        if isempty(old)
            seedFile=fullfile(active,'data','open_cycle_data.mat');
            if ~isfile(seedFile),tpc_collect_continuous(cfg,seedFile);end
            old=load(seedFile,'records');
        end
        steady=[];
        for k=1:numel(old.records)
            q=old.records{k};if q.Rload~=R,continue;end
            late=q.t>=q.t(end)-.002;steady(end+1,:)=[mean(q.a(late,4:3+cfg.nu),1),mean(q.a(late,2))]; %#ok<AGROW>
        end
        fit=[steady(:,1:cfg.nu),ones(size(steady,1),1)]\steady(:,end);
        nominal=cfg.nominalDuty(:)';gradient=fit(1:cfg.nu)';
        center=nominal+(cfg.Vref-[nominal,1]*fit)*gradient/sum(gradient.^2);
        assert(all(abs(center-nominal)<.04),'New operating point exceeds local calibration.');
        rng(172610+round(R));K=2000;sequence=zeros(K+1,cfg.nu);
        for channel=1:cfg.nu
            k=1;while k<=K
                count=randi([1 8]);step=.015*randi([-1 1]);last=min(K,k+count-1);sequence(k:last,channel)=step;k=last+1;
            end
        end
        assert(all(center-.015>=0)&&all(center+.015<=cfg.dutyMax(:)'), 'Excitation exceeds allowed PWM range.');
        warm=.25;times=[0;warm+(0:K)'*cfg.Ts];values=[center;center+sequence];stop=warm+(K+1)*cfg.Ts;
        testCfg=cfg;testCfg.caseDir=fullfile(dest,sprintf('R%g',R));testCfg.codeDir=fullfile(testCfg.caseDir,'code');
        if ~isfolder(testCfg.codeDir),mkdir(testCfg.codeDir);end
        mdl=tpc_make_plant(testCfg,R,'open');set_param(mdl,'MaxStep','1e-7');
        set_param([mdl '/TPC_FullTrace'],'SampleTime','1e-7');
        for channel=1:cfg.nu
        path=[mdl '/TPC_Command_' num2str(channel)];ports=get_param(path,'PortHandles');line=get_param(ports.Outport(1),'Line');portsDst=get_param(line,'DstPortHandle');delete_line(line);delete_block(path);
        add_block('simulink/Sources/From Workspace',path,'VariableName',sprintf('TPC_PRBS_%d',channel),'Interpolate','off',...
            'OutputAfterFinalValue','Holding final value','Position',[1800 160 1850 190]);
        ports=get_param(path,'PortHandles');for p=portsDst(:)',if p>0,add_line(mdl,ports.Outport(1),p,'autorouting','on');end;end
        end
        tpc_clean_root(mdl);save_system(mdl);
        in=Simulink.SimulationInput(mdl);for channel=1:cfg.nu,in=in.setVariable(sprintf('TPC_PRBS_%d',channel),[times,values(:,channel)]);end
        in=in.setModelParameter('StartTime','0','StopTime',num2str(stop,17));
        fprintf('PRBS_ELECTRICAL_START %s R=%g center=%s\n',caseId,R,mat2str(center,9));
        out=sim(in);ts=out.get('TPC_trace');t=ts.Time(:);a=squeeze(ts.Data);if size(a,1)~=numel(t),a=a';end
        points=find(t>=warm-.005 & t<warm & abs(t/cfg.Ts-round(t/cfg.Ts))<1e-5);
        anchor=struct('x',mean(a(points,1:2),1),'u',center,'Rload',R);
        keep=t>=warm-.005;t=t(keep)-warm;a=a(keep,:);
        save(rawFile,'t','a','anchor','center','cfg','-v7.3');close_system(mdl,0);
        fprintf('PRBS_ELECTRICAL_END %s R=%g anchor=%s\n',caseId,R,mat2str(anchor.x,8));
    end
    ix=find(t>=-1e-10 & abs(t/cfg.Ts-round(t/cfg.Ts))<1e-5);v=a(ix,:);
    X=[v(1:end-1,1:2)-anchor.x,v(1:end-1,4:3+cfg.nu)-center];Y=v(2:end,1:2)-anchor.x;
    split=floor(.7*size(X,1));train=1:split;held=split+1:size(X,1);
    n=numel(train);[~,sig,V]=svd(X(train,:),'econ');sigma=diag(sig);assert(min(sigma)>max(sigma)*1e-8);
    whitening=V*diag(sqrt(n)./sigma);Z=X(train,:)*whitening;ys=max(abs(Y(train,:)),[],1);ys(ys==0)=1;
    rng(42);W=.01*randn(2+cfg.nu,2);
    for step=1:100,W=W-.2*(2/n)*Z'*(Z*W-Y(train,:)./ys);end
    coefficients=(whitening*W).*ys;assert(norm(coefficients-X(train,:)\Y(train,:),inf)<1e-7);
    A=coefficients(1:2,:)';B=coefficients(3:end,:)';f=anchor.x'-A*anchor.x'-B*center(:);
    error=X*coefficients-Y;
    models{j}=struct('A',A,'B',B,'f',f,'Ts',cfg.Ts,'Rload',R,'steadyAnchor',anchor,...
        'trainingSamples',numel(train),'heldoutSamples',numel(held),'trainingRMSE',sqrt(mean(error(train,:).^2,1)),...
        'heldoutRMSE',sqrt(mean(error(held,:).^2,1)),...
        'coordinates','dx=x-x0; du=d-d0; dx_next=A*dx+B*du; physical f is anchor-derived');
    checks{end+1}=models{j}; %#ok<AGROW>
end
file=fullfile(dest,'identified_model.mat');save(file,'models','cfg');
fid=fopen(fullfile(dest,'identification.json'),'w');fprintf(fid,'%s',jsonencode(checks,PrettyPrint=true));fclose(fid);
disp(checks);fprintf('PRBS_IDENTIFICATION_COMPLETE %s\n',caseId);
%% 3. 保存主模型并查看辨识图
save(fullfile(codeDir,'models','identified_model.mat'),'models','cfg');
tpc_show_figures(codeDir,'identify');

end
