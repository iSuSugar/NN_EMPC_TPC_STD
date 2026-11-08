% 本工况唯一的日常参数入口。修改物理参数后需重做辨识、EMPC、采样和训练。
codeDir = fileparts(mfilename('fullpath'));
cfg = struct();

%% 工况、电压与电路
cfg.id = 'SISO_VS_VB';
cfg.Vs = 48;
cfg.Vb = 72;
cfg.Vref = 72;
cfg.refs = 72;
cfg.Rloads = [20; 40];
cfg.L = 0.00011;
cfg.Co = 220e-6;
cfg.fsw = 100000;
cfg.Ts = 1e-05;

%% EMPC预测、权重与约束
cfg.N = 30;
cfg.blockTo = 1;
cfg.Qx = 3;
cfg.QxByRload = [3; 0.03];
cfg.Qy = 3000;
cfg.currentMax = 18;
cfg.currentMin = -0.02;
cfg.voltageMin = -0.01;
cfg.dutyMax = 0.94;

%% 神经网络及辨识范围
cfg.hiddenSizes = [16; 8];
cfg.groupLoadFamilies = true;
cfg.nnVoltageDomain = [67; 77];
cfg.nnCurrentDomain = [-0.02; 18];
cfg.nominalDuty = 0.35;
cfg.calibrateRange = [0; 0.7];
cfg.warmupTime = 0.25;
cfg.segmentTime = 0.01;
cfg.openMaxStep = 5e-07;
cfg.identificationVersion = 'fast_PRBS_measured_deviation_affine_v1';

%% 负载变化、信号与电路模板
cfg.events = [0.03; 0.04];
cfg.source = fullfile(fileparts(codeDir), 'circuit', 'template', 'SISO_VS48_VB72.slx');
cfg.activePwm = {['PWM Generator', char(10), '(DC-DC)1']};
cfg.voltageSensor = 'Voltage Measurement1';
cfg.currentSensor = 'Current Measurement3';
cfg.nu = 1;
cfg.feedbackTiming = 'sample_hold';
cfg.paperFigure = 4;

%% 其他声明与路径
cfg.implementation = 'Isolated local candidate: reidentified PRBS affine model, declared Co/N/Qx/block settings; fixed reference only; startup separately controlled and verified.';
cfg.codeRel = 'EMPC_LOOP/SU_SISO_VS48_VB72/code';
cfg.caseRel = 'EMPC_LOOP/SU_SISO_VS48_VB72';
cfg.codeDir = codeDir;
cfg.caseDir = fileparts(codeDir);

%% 初始化与网络接管（启动峰值单独记录）
initialization = struct();
initialization.Co = cfg.Co;
initialization.currentMax = cfg.currentMax;
initialization.currentMin = cfg.currentMin;
initialization.Qx = cfg.Qx;
initialization.QxByRload = cfg.QxByRload;
initialization.N = cfg.N;
initialization.blockTo = cfg.blockTo;
initialization.warmupDuty = 0.3508;
initialization.startupRamp = 0.04;
initialization.warmup = 0.06;
initialization.modelFile = fullfile(codeDir, 'models', 'identified_model.mat');
initialization.tag = 'C220_weightByLoad';
initialization.controllerDir = codeDir;
initialization.nnVoltageDomain = cfg.nnVoltageDomain;
initialization.nnCurrentDomain = cfg.nnCurrentDomain;

