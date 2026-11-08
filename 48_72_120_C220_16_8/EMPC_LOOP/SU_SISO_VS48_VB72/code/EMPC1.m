function EMPC1()
% 本文件直接包含本步骤的计算过程；参数统一在 parameters.m 修改。
codeDir = fileparts(mfilename('fullpath'));
run(fullfile(codeDir, 'parameters.m'));

% Paper cost and state/input limits, solved offline as an explicit controller.
%% 读取预测模型
S=load(fullfile(cfg.codeDir,'models','identified_model.mat'),'models');teachers={};
%% 缩放、预测约束与代价
scale=[cfg.currentMax;1.2*cfg.Vref];T=diag(scale);costScale=1e6;
for j=1:numel(S.models)
 M=S.models{j};
 for vr=cfg.refs(:)'
  tag=regexprep(sprintf('%s_R%g_V%g_T%gus',cfg.id,M.Rload,vr,cfg.Ts*1e6),'[^a-zA-Z0-9_]','p');file=fullfile(cfg.codeDir,'generated',['empc_' tag '.mat']);
  wrapperName=['Bstep_' tag];rawName=[wrapperName '_scaled'];
  signature=tpc_fingerprint(tpc_cfg_signature(cfg),M,vr);
  if isfile(file)&&isfile(fullfile(cfg.codeDir,'generated',[wrapperName '.m']))
   P=load(file,'teacher','cfg','M');
   if strcmp(tpc_fingerprint(tpc_cfg_signature(P.cfg),P.M,P.teacher.Vref),signature),teachers{end+1}=P.teacher;continue;end %#ok<AGROW>
  end
  lowV=min(-.01,1.01*sum(min(0,M.B(2,:)).*cfg.dutyMax(:)'));
  if isfield(cfg,'voltageMin'),lowV=cfg.voltageMin;end
  lowI=0;if isfield(cfg,'currentMin'),lowI=cfg.currentMin;end
  offset=zeros(2,1);if isfield(M,'f'),offset=T\M.f;end
  model=LTISystem('A',T\M.A*T,'B',T\M.B,'C',[0 1],'D',zeros(1,cfg.nu),'f',offset);
  model.x.min=[lowI;lowV]./scale;model.x.max=[1;1];model.u.min=zeros(cfg.nu,1);if isfield(cfg,'dutyMin'),model.u.min=cfg.dutyMin(:);end;model.u.max=cfg.dutyMax(:);
  model.u.with('block');model.u.block.from=1;model.u.block.to=cfg.blockTo;
  model.y.with('reference');model.y.reference=vr/scale(2);
  model.x.penalty=QuadFunction(diag([tpc_current_weight(cfg,M.Rload)*scale(1)^2,0])/costScale);model.y.penalty=QuadFunction(cfg.Qy*scale(2)^2/costScale);
  model.x.with('initialSet');initialMin=model.x.min;initialMax=model.x.max;
  if isfield(cfg,'explicitInitialVoltageDomain')
   initialMin(2)=cfg.explicitInitialVoltageDomain(1)/scale(2);initialMax(2)=cfg.explicitInitialVoltageDomain(2)/scale(2);
  end
  model.x.initialSet=Polyhedron('lb',initialMin,'ub',initialMax);
%% 生成显式控制器
  ctrl=MPCController(model,cfg.N);fprintf('EMPC_START %s R=%g Vref=%g nu=%d\n',cfg.id,M.Rload,vr,cfg.nu);generationTimer=tic;e=ctrl.toExplicit();elapsed=toc(generationTimer);
  teacher=struct('mode',cfg.id,'Rload',M.Rload,'Vref',vr,'scale',scale,'voltageMin',lowV,'voltageMax',scale(2),'currentMax',scale(1),'functionName',wrapperName,'nu',cfg.nu,'elapsedSeconds',elapsed,'regionCount',e.optimizer.Num);
  save(file,'ctrl','e','M','teacher','cfg');
  % MPT takes a scalar row COUNT, not a row-index vector.
  e.optimizer.trimFunction('primal',cfg.nu);e.optimizer.toMatlab(fullfile(cfg.codeDir,'generated',[rawName '.m']),'primal','obj');
  fid=fopen(fullfile(cfg.codeDir,'generated',[wrapperName '.m']),'w');fprintf(fid,'function [u,region]=%s(x)\nx=x(:);[u,region]=%s(x./%s);\nend\n',wrapperName,rawName,mat2str(scale,17));fclose(fid);
  teachers{end+1}=teacher;fprintf('EMPC_COMPLETE %s regions=%d elapsed=%.2f\n',tag,teacher.regionCount,elapsed); %#ok<AGROW>
 end
end
%% 保存本工况控制器索引
save(fullfile(cfg.codeDir,'models','EMPC_48_72_120.mat'),'teachers','cfg');fid=fopen(fullfile(cfg.codeDir,'results','empc_design.json'),'w');fprintf(fid,'%s',jsonencode(teachers,PrettyPrint=true));fclose(fid);
tpc_show_figures(codeDir,'empc');

end
