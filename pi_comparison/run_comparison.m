function run_comparison(stage)
% No baseline files are written. Existing comparison results are reused.
if nargin<1,stage='all';end
switch stage
 case 'design',audit_pi;design_pi;
 case 'single',run_pi_cases(1:5);
 case 'switch',run_pi_cases(6:9);
 case 'plots',plot_pi_comparison;
 case 'verify',verify_pi_comparison;
 case 'all'
  if ~isfile(fullfile(fileparts(mfilename('fullpath')),'pi_design.mat')),audit_pi;design_pi;end
  run_pi_cases(1:9);plot_pi_comparison;verify_pi_comparison;
 otherwise,error('Use all, design, single, switch, plots or verify.');
end
end
