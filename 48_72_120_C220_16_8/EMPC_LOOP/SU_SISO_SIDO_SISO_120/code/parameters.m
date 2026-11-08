% 本工况唯一的日常参数入口。修改物理参数后需重做辨识、EMPC、采样和训练。
codeDir = fileparts(mfilename('fullpath'));
cfg = struct();

%% 工况、电压与电路
cfg.id = 'SISO_SIDO_SISO_EXTRA';
cfg.Vref = 120;
cfg.Rload = 48;
cfg.L = 0.00011;
cfg.Co = 220e-6;
cfg.Ts = 1e-05;

%% EMPC预测、权重与约束
cfg.fixedDutyS1 = 0.75;

%% 神经网络及辨识范围
cfg.warmupTime = 0.25;

%% 负载变化、信号与电路模板
cfg.events = [0.05; 0.07];
cfg.source = fullfile(fileparts(codeDir), 'circuit', 'template', 'change_SISO_SIDO_SISO.slx');
cfg.feedbackTiming = 'sample_hold';
cfg.paperFigure = 0;

%% 其他声明与路径
cfg.mapping = struct('pwm', {}, 'mode', {}, 'head', {});
cfg.mapping(1).pwm = ['PWM Generator', char(10), '(DC-DC)1'];
cfg.mapping(1).mode = 'SISO_VS_VO';
cfg.mapping(1).head = 1;
cfg.mapping(2).pwm = ['PWM Generator', char(10), '(DC-DC)2'];
cfg.mapping(2).mode = 'SIDO';
cfg.mapping(2).head = 1;
cfg.codeRel = 'EMPC_LOOP/SU_SISO_SIDO_SISO_120/code';
cfg.caseRel = 'EMPC_LOOP/SU_SISO_SIDO_SISO_120';
cfg.mapping = cfg.mapping(:);
cfg.codeDir = codeDir;
cfg.caseDir = fileparts(codeDir);

%% 初始化与网络接管（启动峰值单独记录）
initialization = struct();

