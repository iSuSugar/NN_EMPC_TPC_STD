function tpc_export_figure_pdf(fig,path)
% Fixed-page printing avoids R2024b exportgraphics PDF tile/label clipping.
% The page follows the figure's physical aspect ratio; print retains vector
% text/lines where supported and renders complex surfaces at 450 dpi.
oldUnits=get(fig,'Units');set(fig,'Units','inches');position=get(fig,'Position');set(fig,'Units',oldUnits);
pageSize=position(3:4);assert(all(pageSize>0));
set(fig,'PaperUnits','inches','PaperSize',pageSize,...
 'PaperPosition',[0 0 pageSize],'PaperPositionMode','manual','InvertHardcopy','off');
print(fig,path,'-dpdf','-r450');
end
