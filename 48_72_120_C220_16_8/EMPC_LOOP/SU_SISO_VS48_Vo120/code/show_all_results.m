function show_all_results()
% 只读已保存结果，不重新仿真或训练。
codeDir=fileparts(mfilename('fullpath'));
tpc_show_figures(codeDir,'all');
end
