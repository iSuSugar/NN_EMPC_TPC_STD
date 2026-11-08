function project_entry(action,x)
% Unified entry point for the copied main project. Default: show commands.
if nargin<1,action='help';end
project_root=fileparts(mfilename('fullpath'));
initial_folder=pwd;initial_path=path;
cleanup=onCleanup(@()restore_project_environment(initial_folder,initial_path)); %#ok<NASGU>
cases_root=fullfile(project_root,'02_仿真工程');
siso_case=fullfile(cases_root,'01_SISO_VsVo');
switch lower(char(action))
 case 'help'
  fprintf('Main project: %s\n',project_root);
  fprintf('Views: siso, vbvo, vsvb, sido, diso, switching, pid\n');
  fprintf('SISO: empc ([iL;Vo]), baseline, study, plots\n');
  fprintf('Other runs: run_pair, run_sido, run_diso, run_switching\n');
  fprintf('Start reading: %s\n',fullfile(project_root,'开始这里.md'));
 case {'siso','empc','baseline','study','plots'}
  cd(siso_case);addpath(siso_case,'-begin');
  mode=lower(char(action));if strcmp(mode,'siso'),mode='view';end
  if strcmp(mode,'empc')&&nargin>=2,run_siso_case(mode,x);else,run_siso_case(mode);end
 case {'vbvo','vsvb'}
  pair_case=fullfile(cases_root,'02_SISO_VBVo与VsVB','结果');
  if strcmpi(action,'vbvo'),model_file=fullfile(pair_case,'SISO_VB72_Vo200','SISO_VB72V_Vo200V_study.slx');
  else,model_file=fullfile(pair_case,'SISO_VS48_VB72','SISO_VS48_VB72_study.slx');end
  open_system(model_file);
 case 'sido'
  open_system(fullfile(cases_root,'03_SIDO','结果','SIDO_VS_VBVo_study.slx'));
 case 'diso'
  open_system(fullfile(cases_root,'04_DISO','结果','DISO_VS270W_VB30W','DISO_VS270W_VB30W_study.slx'));
 case 'run_pair'
  run(fullfile(cases_root,'02_SISO_VBVo与VsVB','脚本','run_siso_pair.m'));
 case 'run_sido'
  run(fullfile(cases_root,'03_SIDO','脚本','run_sido.m'));
 case 'run_diso'
  run(fullfile(cases_root,'04_DISO','脚本','run_diso.m'));
 case 'switching'
  open_system(fullfile(cases_root,'05_模式切换','结果','change_SISO_SIDO_SISO_study.slx'));
 case 'pid'
  open_system(fullfile(cases_root,'06_PID对照','模型与算法','SISO_VS48_Vo200_duibi.slx'));
 case 'run_switching'
  run(fullfile(cases_root,'05_模式切换','脚本','run_switching.m'));
 otherwise,error('Unknown action. Call project_entry(''help'').');
end
end
function restore_project_environment(folder,search_path)
cd(folder);path(search_path);
end
