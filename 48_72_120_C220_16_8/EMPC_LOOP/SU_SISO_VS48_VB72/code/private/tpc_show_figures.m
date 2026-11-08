function paths=tpc_show_figures(codeDir,viewName,manageVisibility)
% Small default view. Detailed diagnostics are retained and opened on request.
if nargin<2,viewName='summary';end
if nargin<3,manageVisibility=true;end
root=tpc_project_root();
cfg=tpc_load_case(codeDir);switching=isfield(cfg,'mapping');
cfgFile='case_config.json';if switching,cfgFile='switch_config.json';end
cfg=tpc_load_case(codeDir);desktop=usejava('desktop');paths={};
if desktop&&manageVisibility,hideOwnedFigures();end
if strcmp(viewName,'all')
 tpc_publication_figures(codeDir,'all','all');
 fprintf('必要证据图已打开；重复诊断图不再生成。平时运行 show_results 只看两张结果图。\n');return;
end
if any(strcmp(viewName,{'summary','closed'}))
 folder=fullfile(codeDir,'results','summary');if ~isfolder(folder),mkdir(folder);end
 source=fullfile(codeDir,'results','figures');
 files={fullfile(source,'07_closed_loop.fig'),fullfile(source,'08_event_enlargements.fig')};
 if ~all(cellfun(@isfile,files)),tpc_publication_figures(codeDir,'closed');end
 assert(all(cellfun(@isfile,files)),'请先运行 run_closed_loop 生成电路结果。');
 report=jsondecode(fileread(fullfile(codeDir,'results','switching_dynamic.json')));
 names={'01_闭环总览','02_变化处电压放大'};
 descriptions={'看电压是否稳住，以及电感电流和占空比怎样变化','只看两次变化引起的电压跌落、超调与恢复'};
 for j=1:2
  destination=fullfile(folder,[names{j} '.fig']);deps=dir(files{j});old=dir(destination);self=dir([mfilename('fullpath') '.m']);
  stale=isempty(old)||old.datenum<max(deps.datenum,self.datenum);
  if stale
   original=openfig(files{j},'invisible');cleanup=onCleanup(@()closeIfValid(original));
   if j==1
    fig=newFigure([modeName() '｜闭环总览'],1180,760);tiledlayout(3,1,'TileSpacing','compact','Padding','compact');
    sourceTiles=[1 2 4];labels={'输出电压 / V','电感电流 / A','占空比命令'};
    if strcmp(cfg.id,'SISO_VS_VB'),labels{1}='电池电压 / V';end
    for row=1:3
     ax=nexttile;copyPlot(original,sourceTiles(row),ax);ylabel(ax,labels{row});
     for event=cfg.events(:)',xline(ax,event*1e3,':','Color',[.4 .4 .4]);end
     if row==1,title(ax,[modeName() '：稳态电压是否达到给定值'],'Interpreter','none');end
     if row==3
      xlabel(ax,'反馈接管后的时间 / ms');lines=flipud(findobj(ax,'Type','line'));
      if numel(lines)>1,legend(ax,lines,compose('命令%d',1:numel(lines)),'Location','best');end
     end
    end
   else
    fig=newFigure([modeName() '｜变化处电压放大'],1180,450);tiledlayout(1,numel(cfg.events),'TileSpacing','compact','Padding','compact');
    for event=1:numel(cfg.events)
     ax=nexttile;copyPlot(original,event,ax);xlabel(ax,'相对变化时刻 / us');ylabel(ax,'电压 / V');
     e=report.events(event);title(ax,sprintf('变化%d（%.3g ms）\n电压偏差 %.3g V；恢复 %.3g us',event,cfg.events(event)*1e3,e.peakDepartureV,e.settlingToPostUs));
     lines=flipud(findobj(ax,'Type','line'));
     if numel(lines)==2,legend(ax,lines,{'开关原始波形','完整PWM周期均值'},'Location','best');end
    end
   end
   set(fig,'Tag',['TPC_VIEW_' cfg.id '_' num2str(j)]);
   savefig(fig,destination);exportgraphics(fig,fullfile(folder,[names{j} '.png']),'Resolution',450);close(fig);clear cleanup;
  end
  paths{end+1}=destination; %#ok<AGROW>
  showSaved(destination,sprintf('%s｜图%d %s',modeName(),j,names{j}(4:end)),['TPC_VIEW_' cfg.id '_' num2str(j)]);
  fprintf('图%d【%s】：%s。\n',j,names{j}(4:end),descriptions{j});
 end
 fprintf('默认只显示以上两张图；详细图仍在 results/figures，需要时运行 show_all_results。\n');
 return;
end
if switching
 C=tpc_read_cases(fullfile(root,'config','target_cases.json'));
 for mode=unique({cfg.mapping.mode})
  k=find(strcmp({C.id},mode{1}),1);more=tpc_show_figures(C(k).codeDir,viewName,false);paths=[paths more]; %#ok<AGROW>
 end
 return;
end
if strcmp(viewName,'samples')
 fprintf('训练样本已保存；不再生成单独的样本分布图，下一阶段查看网络拟合结果。\n');return;
end
choices=struct('identify',{{'01_identification','模型辨识：预测能否跟上测量'}},...
 'empc',{{'03_empc_control_law','EMPC控制律：不同状态对应什么占空比'}},...
 'samples',{{'04_sample_distribution','训练样本：数据覆盖哪些状态'}},...
 'network',{{'05_neural_fit','网络拟合：收敛、散点与误差'}});
assert(isfield(choices,viewName),'Unknown figure view: %s',viewName);choice=choices.(viewName);
% Stages have just updated their inputs; keep archived diagnostics current,
% but do not open all of them. Only this stage's necessary figure is shown.
tpc_publication_figures(codeDir,viewName);
path=fullfile(codeDir,'results','figures',[choice{1} '.fig']);
if isfile(path)
 paths={path};showSaved(path,[modeName() '｜' choice{2}],[cfg.id '_' choice{1}]);fprintf('本阶段只显示【%s】。\n',choice{2});
end

 function fig=newFigure(name,w,h)
  fig=figure('Name',name,'NumberTitle','off','Visible','off','Color','w','Position',[70 70 w h],...
   'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei','DefaultAxesFontSize',11);
 end
 function copyPlot(original,tile,ax)
  axesList=findall(original,'Type','axes');match=[];
  for k=1:numel(axesList),if isequal(axesList(k).Layout.Tile,tile),match=axesList(k);break;end;end
  assert(~isempty(match),'Saved source panel unavailable: %d',tile);
  copyobj(allchild(match),ax);set(ax,'XLim',match.XLim,'YLim',match.YLim,'XScale',match.XScale,'YScale',match.YScale,...
   'FontName','Microsoft YaHei','FontSize',11,'TickDir','out','LineWidth',.8,'GridAlpha',.12);grid(ax,'on');box(ax,'on');
 end
 function showSaved(path,name,tag)
  if ~desktop,return;end
  old=findall(groot,'Type','figure','Tag',tag);
  if isempty(old),fig=openfig(path,'new','invisible');else,fig=old(1);end
  set(fig,'Name',name,'NumberTitle','off','Tag',tag,'WindowStyle','docked','Visible','on');drawnow;
 end
 function hideOwnedFigures()
  % Hide our tabs only, preserving edits and all unrelated user figures.
  allFigures=findall(groot,'Type','figure');
  cases=tpc_read_cases(fullfile(root,'config','target_cases.json'));switches=tpc_read_cases(fullfile(root,'config','switch_cases.json'));
  ids=[{cases.id} {switches.id}];
  for k=1:numel(allFigures)
   tag=get(allFigures(k),'Tag');owned=startsWith(tag,'TPC_VIEW_');
   for id=ids,owned=owned||~isempty(regexp(tag,['^' id{1} '_(0[1-9]|10)_'],'once'));end
   if owned,set(allFigures(k),'Visible','off');end
  end
 end
 function name=modeName()
  switch cfg.id
   case 'SISO_VS_VB',name='48 V电源 → 72 V电池';
   case 'SISO_VS_VO',name='48 V电源 → 120 V负载';
   case 'SISO_VB_VO',name='72 V电池 → 120 V负载';
   case 'SIDO',name='SIDO：电源给电池及负载供能';
   case 'DISO',name='DISO：电源与电池共同供能';
   otherwise,name=['模式切换：' strrep(erase(cfg.id,'_EXTRA'),'_',' → ')];
  end
 end
end
function closeIfValid(fig),if isgraphics(fig),close(fig);end;end
