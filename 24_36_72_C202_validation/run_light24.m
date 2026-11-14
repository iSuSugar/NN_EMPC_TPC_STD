function run_light24()
% Explicit light-load CCM/DCM check. Open-loop voltage is not regulated here.
here=fileparts(mfilename('fullpath'));source=fullfile(here,'results','SISO_VS_VO','OPEN_SISO_VS_VO_vgs_proxy.slx');
folder=fullfile(here,'results','ccm_boundary');if ~isfolder(folder),mkdir(folder);end
for current=[.1 .2 .5]
 tag=sprintf('Io%gmA',current*1000);file=fullfile(folder,[tag '.mat']);if isfile(file),continue;end
 name=['LIGHT24_' tag];dest=fullfile(folder,[name '.slx']);h=load_system(source);save_system(h,dest);close_system(h,0);load_system(dest);
 mw=get_param(name,'ModelWorkspace');assignin(mw,'LOAD_SEQUENCE',[0 0;.03 current;.09 current]);set_param(name,'StopTime','.09');save_system(name);
 fprintf('LIGHT24_START %s\n',tag);out=sim(name);z=out.get('TPC_trace');t=z.Time(:);a=squeeze(z.Data);if size(a,1)~=numel(t),a=a';end
 w=t>=.085&t<.089;i=a(w,1);g=floor((t(w)+1e-12)*1e5);[~,~,bins]=unique(g);mn=accumarray(bins,i,[],@min);mx=accumarray(bins,i,[],@max);
 report=struct('setLoadCurrent',current,'actualLoadCurrent',mean(a(w,3)),'meanVoltage',mean(a(w,2)),'meanCurrent',mean(i),'rmsCurrent',sqrt(mean(i.^2)),'minimumCurrent',min(i),'maximumCurrent',max(i),'meanCycleRipple',mean(mx-mn),'fractionCCMcyclesAbove20mA',mean(mn>.02),'fractionNearZero',mean(abs(i)<.02),'note','Fixed duty0.7522, not72V regulation; final voltage may drift at light load.');
 assert(abs(report.actualLoadCurrent-current)<.02);raw=t>=.0898;rawT=t(raw);rawA=a(raw,:);save(file,'rawT','rawA','report','-v7.3');fid=fopen(fullfile(folder,[tag '.json']),'w');fprintf(fid,'%s',jsonencode(report,PrettyPrint=true));fclose(fid);close_system(name,0);
 fprintf('LIGHT24_COMPLETE %s Vo=%g Imin=%g CCMfraction=%g\n',tag,report.meanVoltage,report.minimumCurrent,report.fractionCCMcyclesAbove20mA);
end
end
