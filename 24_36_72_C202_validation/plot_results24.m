function summary=plot_results24()
here=fileparts(mfilename('fullpath'));folder=fullfile(here,'figures');if ~isfolder(folder),mkdir(folder);end
set(groot,'defaultAxesFontName','SimSun','defaultTextFontName','SimSun');ref=jsondecode(fileread(fullfile(here,'experiment_reference.json')));summary=struct('open',{{}},'closed',{{}});
for k=1:numel(ref.cases)
 if iscell(ref.cases),c=ref.cases{k};else,c=ref.cases(k);end;A=load(fullfile(here,'results',c.id,'open_command.mat'));B=load(fullfile(here,'results',c.id,'open_vgs_proxy.mat'));
 f=figure('Visible','off','Color','w','Position',[100 100 1100 700]);tiledlayout(2,2,'TileSpacing','compact','Padding','loose');
 nexttile;plot(A.tc*1e3,A.ac(:,2),'LineWidth',1.3);hold on;plot(B.tc*1e3,B.ac(:,2),'--','LineWidth',1.3);grid on;xlabel('时间 / ms');ylabel('周期平均电压 / V');legend('FPGA命令','VGS脉宽代理','Location','best');
 nexttile;plot(A.tc*1e3,A.ac(:,1),'LineWidth',1.3);hold on;plot(B.tc*1e3,B.ac(:,1),'--','LineWidth',1.3);grid on;xlabel('时间 / ms');ylabel('周期平均电感电流 / A');
 for n=1:2
  nexttile;te=.06;if n==2,te=.08;end
  for data={A,B}
   D=data{1};t=D.rawT;w=t>=te-30e-6&t<te;tt=(t(w)-(te-30e-6))*1e6;plot(tt,D.rawA(w,1),'LineWidth',1.2);hold on;
  end
  yline(0,'k:');grid on;xlabel('局部时间 / μs');ylabel('原始电感电流 / A');title(sprintf('%.1f A负载，连续3个PWM周期',.5+.5*(n==2)));
 end
 sgtitle([c.id '  24/36 V开环对照'],'Interpreter','none');exportgraphics(f,fullfile(folder,[c.id '_open.png']),'Resolution',220);savefig(f,fullfile(folder,[c.id '_open.fig']));close(f);
 summary.open{k}=struct('id',c.id,'command',A.report,'vgsProxy',B.report,'measuredVoltage',c.VoMeasured_V);
end
files=dir(fullfile(here,'results','closed72','*.mat'));
for k=1:numel(files)
 D=load(fullfile(files(k).folder,files(k).name));r=D.report;summary.closed{k}=r;
 f=figure('Visible','off','Color','w','Position',[100 100 1050 850]);tiledlayout(3,1,'TileSpacing','compact','Padding','loose');
 nexttile;plot(D.tc*1e3,D.ac(:,2),'LineWidth',1.4);hold on;yline(72,'k--');grid on;ylabel('输出电压 / V');title(['24 V到72 V独立PI仿真  ' r.case],'Interpreter','none');
 nexttile;plot(D.tc*1e3,D.ac(:,1),'LineWidth',1.4);grid on;ylabel('电感周期平均电流 / A');
 nexttile;plot(D.tc*1e3,D.ac(:,4),'LineWidth',1.4);grid on;ylabel('施加占空比');xlabel('时间 / ms');
 exportgraphics(f,fullfile(folder,['closed_' r.case '.png']),'Resolution',220);savefig(f,fullfile(folder,['closed_' r.case '.fig']));close(f);
 if strcmp(r.case,'C202_delay0ns')
  f=figure('Visible','off','Color','w','Position',[100 100 1100 440]);tiledlayout(1,2,'TileSpacing','compact','Padding','loose');
  for j=1:2
   te=.06;if j==2,te=.08;end;w=D.rawT>=te-30e-6&D.rawT<te;nexttile;plot((D.rawT(w)-te+30e-6)*1e6,D.rawA(w,1),'LineWidth',1.5);hold on;yline(0,'k--');grid on;xlim([0 30]);xlabel('连续3周期 / μs');ylabel('电感电流 / A');title(sprintf('72 V闭环，负载%.1f A',.5*j));
  end
  sgtitle('110 μH与202 μF下的电感电流核对');exportgraphics(f,fullfile(folder,'closed72_inductor.png'),'Resolution',220);savefig(f,fullfile(folder,'closed72_inductor.fig'));close(f);
 end
end
fid=fopen(fullfile(here,'summary24.json'),'w');fprintf(fid,'%s',jsonencode(summary,PrettyPrint=true));fclose(fid);
f=figure('Visible','off','Color','w','Position',[100 100 1100 500]);tiledlayout(1,3,'TileSpacing','compact','Padding','loose');
for current=[.1 .2 .5]
 D=load(fullfile(here,'results','ccm_boundary',sprintf('Io%gmA.mat',current*1000)));nexttile;t=D.rawT;w=t>=.0899;t=(t(w)-.0899)*1e6;plot(t,D.rawA(w,1),'LineWidth',1.3);hold on;yline(0,'k--');grid on;xlim([0 30]);xlabel('局部时间 / μs');ylabel('电感电流 / A');title(sprintf('负载%.1f A  输出约%.1f V',current,D.report.meanVoltage));
end
sgtitle('固定占空比0.7522下轻载导通模式对照');exportgraphics(f,fullfile(folder,'CCM_DCM.png'),'Resolution',220);savefig(f,fullfile(folder,'CCM_DCM.fig'));close(f);
rows={};for k=1:numel(summary.open),s=summary.open{k};for variant={'command','vgsProxy'},r=s.(variant{1});for n=1:2,p=r.plateaus(n);rows(end+1,:)={s.id,variant{1},.5*n,p.meanVoltage,p.meanCurrent,p.rmsCurrent,p.minCurrent,p.peakCurrent,p.meanCycleRipple,p.fractionCyclesAbove20mA,s.measuredVoltage(n)};end;end;end
T=cell2table(rows,'VariableNames',{'Mode','DutyCase','Load_A','SimVoltage_V','ILmean_A','ILrms_A','ILmin_A','ILmax_A','Ripple_A','CCMcycleFraction','PPTVoltage_V'});writetable(T,fullfile(here,'open_current_comparison.csv'));
fprintf('PLOT24_COMPLETE open=%d closed=%d\n',numel(summary.open),numel(summary.closed));
end
