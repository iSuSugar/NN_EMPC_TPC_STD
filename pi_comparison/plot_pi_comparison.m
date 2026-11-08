function summary=plot_pi_comparison()
here=fileparts(mfilename('fullpath'));outdir=fullfile(here,'figures');if ~isfolder(outdir),mkdir(outdir);end
order={'SISO_VS_VO','SISO_VB_VO','SISO_VS_VB','SIDO','DISO','SIDO_SISO_SIDO','DISO_SISO_DISO','DISO_SIDO_DISO','SISO_SIDO_SISO_EXTRA'};
titles={'48 V电源到120 V负载','72 V电池到120 V负载','48 V电源到72 V电池端','SIDO','DISO','SIDO到SISO到SIDO','DISO到SISO到DISO','DISO到SIDO到DISO','SISO到SIDO到SISO'};
summary=cell(numel(order),1);set(groot,'defaultAxesFontName','SimSun','defaultTextFontName','SimSun');
for k=1:numel(order)
 folder=fullfile(here,'results',order{k});N=load(fullfile(folder,'NN.mat'));P=load(fullfile(folder,'PI.mat'));
 assert(isequal(N.cfg.events,P.cfg.events)&&N.cfg.Ts==P.cfg.Ts&&N.cfg.Vref==P.cfg.Vref);
 f=figure('Visible','off','Color','w','Position',[100 100 1000 400]);tiledlayout(1,2,'TileSpacing','compact','Padding','loose');
 for j=1:2
  nexttile;te=N.cfg.events(j);tn=(N.tc-te)*1e6;tp=(P.tc-te)*1e6;
  m=tn>=-400&tn<=3000;h1=plot(tn(m),N.ac(m,2),'Color',[0 .32 .65],'LineWidth',1.5);hold on;
  m=tp>=-400&tp<=3000;h2=plot(tp(m),P.ac(m,2),'Color',[.8 .25 .05],'LineWidth',1.5,'LineStyle','--');
  yline(N.cfg.Vref,'k:','LineWidth',.8);xline(0,'k:');grid on;xlim([-400 3000]);xlabel('相对事件时刻 / μs');ylabel('PWM周期平均电压 / V');
  title(sprintf('事件%d  %.0f ms',j,te*1e3));legend([h1 h2],{'NN–EMPC','双环PI'},'Location','best','Box','off','FontSize',13);set(gca,'FontSize',14,'XTick',[0 1000 2000 3000]);
 end
 label=titles{k};if k<=5,label=sprintf('%s，负载 %g→%g→%g Ω',label,2*N.cfg.Rloads(1),N.cfg.Rloads(1),2*N.cfg.Rloads(1));else,label=[label '，负载48 Ω'];end
 sgtitle(label,'FontSize',17,'Color','k');stem=sprintf('%02d_%s',k,order{k});
 exportgraphics(f,fullfile(outdir,[stem '.png']),'Resolution',300);savefig(f,fullfile(outdir,[stem '.fig']));close(f);
 summary{k}=struct('id',order{k},'title',titles{k},'figure',['figures/' stem '.png'],'NN',N.report,'PI',P.report);
 fprintf('PI_COMPARISON_PLOT %s\n',order{k});
end
fid=fopen(fullfile(here,'comparison_summary.json'),'w');fprintf(fid,'%s',jsonencode(summary,PrettyPrint=true));fclose(fid);
rows={};for k=1:numel(summary),s=summary{k};for kind={'NN','PI'},r=s.(kind{1});for j=1:numel(r.events),e=r.events(j);rows(end+1,:)={s.id,kind{1},j,e.time,r.maximumPlateauErrorPct,e.peakDepartureV,e.recoveryUs,e.IAE_Vs,r.feedbackPeakCurrentA};end;end;end
T=cell2table(rows,'VariableNames',{'Mode','Controller','Event','Time_s','MaxPlateauError_pct','PeakDeparture_V','Recovery_us','IAE_Vs','FeedbackPeakCurrent_A'});writetable(T,fullfile(here,'comparison_metrics.csv'));
end
