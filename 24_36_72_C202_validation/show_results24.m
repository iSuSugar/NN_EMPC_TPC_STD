function show_results24(includeLightLoad)
% Open only the two essential figures by default; do not rerun simulations.
if nargin<1,includeLightLoad=false;end
here=fileparts(mfilename('fullpath'));names={'closed_C202_delay0ns.fig','closed72_inductor.fig'};
if includeLightLoad,names{end+1}='CCM_DCM.fig';end
for k=1:numel(names),openfig(fullfile(here,'figures',names{k}),'new','visible');end
end
