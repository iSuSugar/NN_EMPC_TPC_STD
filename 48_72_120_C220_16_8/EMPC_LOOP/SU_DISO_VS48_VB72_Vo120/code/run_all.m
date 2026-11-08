function run_all()
% 按原工程顺序执行本工况全部步骤。
codeDir=fileparts(mfilename('fullpath'));old=pwd;cd(codeDir);cleanup=onCleanup(@()cd(old));
model_calculate;
EMPC1;
train_sample;
zhenghe;
myguiyihua;
run_closed_loop;
end
