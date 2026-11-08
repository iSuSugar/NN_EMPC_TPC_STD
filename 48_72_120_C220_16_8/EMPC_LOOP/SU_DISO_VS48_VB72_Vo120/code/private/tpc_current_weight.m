function value=tpc_current_weight(cfg,Rload)
% Optional load-dependent tuning, selected by measured load, never time.
value=cfg.Qx;
if isfield(cfg,'QxByRload')
 assert(numel(cfg.QxByRload)==numel(cfg.Rloads));[distance,j]=min(abs(cfg.Rloads(:)-Rload));
 assert(distance<1e-8);value=cfg.QxByRload(j);
end
end
