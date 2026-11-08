function designs=design_pi()
% Tune on the same identified plants, not on NN test outcomes.
here=fileparts(mfilename('fullpath'));C=jsondecode(fileread(fullfile(here,'audit.json')));if ~iscell(C),C=num2cell(C);end
designs=cell(numel(C),1);
opts=pidtuneOptions('PhaseMargin',60,'DesignFocus','disturbance-rejection');
for k=1:numel(C)
 c=C{k};cfg=c.cfg;M=c.models;if iscell(M),M=vertcat(M{:});end;Ts=cfg.Ts;
 [~,full]=min([M.Rload]);[~,half]=max([M.Rload]);B=M(full).B;if cfg.nu==1,B=B(:);end
 direction=B(1,:)';direction=direction/norm(direction);
 G=ss(M(full).A,B*direction,eye(2),zeros(2,1),Ts);Gi=G(1);Gv=G(2);
 base=pid(1,1,0,'Ts',Ts,'IFormula','ForwardEuler');
 candidates={};best=inf;selected=[];
 for fi=[1000 2000 4000]
  try,[Ci,ii]=pidtune(Gi,base,2*pi*fi,opts);catch,continue;end
  outer=minreal(Gv*feedback(Ci,Gi),1e-7);
  for fv=[100 250 500 800]
   if fv>fi/4,continue;end
   try,[Cv,vi]=pidtune(outer,base,2*pi*fv,opts);catch,continue;end
   p=struct('id',cfg.id,'KpI',Ci.Kp,'KiI',Ci.Ki,'KpV',Cv.Kp,'KiV',Cv.Ki,...
    'direction',direction,'uBase',c.initialization.warmupDuty(:),'iBase',M(half).anchor.x(1),...
    'innerHz',fi,'outerHz',fv,'innerPhaseMargin',ii.PhaseMargin,'outerPhaseMargin',vi.PhaseMargin,...
    'Ts',Ts,'Vref',cfg.Vref,'currentMin',cfg.currentMin,'currentMax',cfg.currentMax,...
    'uMin',zeros(cfg.nu,1),'uMax',cfg.dutyMax(:));
   if isfield(cfg,'dutyMin')&&~isempty(cfg.dutyMin),p.uMin=cfg.dutyMin(:);end
   radius=zeros(numel(M),1);
   for j=1:numel(M)
    Bj=M(j).B;if cfg.nu==1,Bj=Bj(:);end;bd=Bj*direction;
    aug=[M(j).A+bd*Ci.Kp*[-1 -Cv.Kp],bd,bd*Ci.Kp;Ts*Ci.Ki*[-1 -Cv.Kp],1,Ts*Ci.Ki;0,-Ts*Cv.Ki,0,1];
    radius(j)=max(abs(eig(aug)));
   end
   if any(radius>=1)||any([Ci.Kp Ci.Ki Cv.Kp Cv.Ki]<=0),continue;end
   score=linearScore(p,M,full,half);p.modelScore=score;p.maximumPoleRadius=max(radius);
   candidates{end+1}=p; %#ok<AGROW>
   if score<best,best=score;selected=p;end
  end
 end
 assert(~isempty(selected),'No stable PI candidate for %s',cfg.id);
 designs{k}=selected;fprintf('PI_DESIGN %s KpI=%g KiI=%g KpV=%g KiV=%g inner=%g outer=%g rho=%g\n',cfg.id,selected.KpI,selected.KiI,selected.KpV,selected.KiV,selected.innerHz,selected.outerHz,selected.maximumPoleRadius);
 fid=fopen(fullfile(here,['tuning_' cfg.id '.json']),'w');fprintf(fid,'%s',jsonencode(candidates,PrettyPrint=true));fclose(fid);
end
save(fullfile(here,'pi_design.mat'),'designs');fid=fopen(fullfile(here,'pi_design.json'),'w');fprintf(fid,'%s',jsonencode(designs,PrettyPrint=true));fclose(fid);
end
function score=linearScore(p,M,full,half)
x=M(half).anchor.x(:);zi=0;zv=0;errs=zeros(3000,1);imax=0;
for k=1:3000
 j=half;if k>=1001&&k<=2000,j=full;end
 ev=p.Vref-x(2);ir0=p.iBase+p.KpV*ev+zv;ir=min(max(ir0,p.currentMin),p.currentMax);
 ei=ir-x(1);q=p.KpI*ei+zi;u=min(max(p.uBase+p.direction*q,p.uMin),p.uMax);qa=p.direction'*(u-p.uBase);
 zi=zi+p.KiI*p.Ts*ei+.2*(qa-q);
 if ~((ir0>p.currentMax&&ev>0)||(ir0<p.currentMin&&ev<0)||(qa<q-1e-12&&ev>0)||(qa>q+1e-12&&ev<0)),zv=zv+p.KiV*p.Ts*ev;end
 B=M(j).B;if numel(p.uBase)==1,B=B(:);end
 x=M(j).A*x+B*u+M(j).f(:);errs(k)=abs(p.Vref-x(2));imax=max(imax,abs(x(1)));
 if ~all(isfinite(x))||max(abs(x))>1e4,score=inf;return;end
end
score=mean(errs(500:end))+.05*max(errs(500:end))+max(0,imax-p.currentMax);
end
