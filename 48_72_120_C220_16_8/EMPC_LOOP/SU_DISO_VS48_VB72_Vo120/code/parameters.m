% 本工况唯一的日常参数入口。修改物理参数后需重做辨识、EMPC、采样和训练。
codeDir = fileparts(mfilename('fullpath'));
cfg = struct();

%% 工况、电压与电路
cfg.id = 'DISO';
cfg.Vs = 48;
cfg.Vb = 72;
cfg.Vref = 120;
cfg.refs = 120;
cfg.Rloads = [48; 96];
cfg.L = 0.00011;
cfg.Co = 220e-6;
cfg.fsw = 100000;
cfg.Ts = 1e-05;

%% EMPC预测、权重与约束
cfg.N = 20;
cfg.blockTo = 1;
cfg.Qx = 0.03;
cfg.Qy = 5000;
cfg.currentMax = 18;
cfg.currentMin = -0.02;
cfg.voltageMin = -0.01;
cfg.dutyMin = [0.335; 0.179];
cfg.dutyMax = [0.42; 0.27];
cfg.explicitInitialVoltageDomain = [115; 125];

%% 神经网络及辨识范围
cfg.hiddenSizes = [16; 8];
cfg.groupLoadFamilies = true;
cfg.nnVoltageDomain = [115; 125];
cfg.nnCurrentDomain = [-0.02; 18];
cfg.nominalDuty = [0.362; 0.205];
cfg.calibrateRange = [0.2; 1.35];
cfg.warmupTime = 0.25;
cfg.segmentTime = 0.01;
cfg.openMaxStep = 5e-07;
cfg.identificationVersion = 'fast_PRBS_measured_deviation_affine_v1';

%% 负载变化、信号与电路模板
cfg.events = [0.05; 0.06];
cfg.source = fullfile(fileparts(codeDir), 'circuit', 'template', 'DISO_VS270W_VB30W.slx');
cfg.activePwm = {['PWM Generator', char(10), '(DC-DC)']; ['PWM Generator', char(10), '(DC-DC)2']};
cfg.voltageSensor = 'Voltage Measurement';
cfg.currentSensor = 'Current Measurement3';
cfg.nu = 2;
cfg.feedbackTiming = 'sample_hold';
cfg.paperFigure = 8;

%% 其他声明与路径
cfg.implementation = 'Isolated local candidate: reidentified PRBS affine model, declared Co/N/Qx/block settings; fixed reference only; startup separately controlled and verified.';
cfg.codeRel = 'EMPC_LOOP/SU_DISO_VS48_VB72_Vo120/code';
cfg.caseRel = 'EMPC_LOOP/SU_DISO_VS48_VB72_Vo120';
cfg.codeDir = codeDir;
cfg.caseDir = fileparts(codeDir);

%% 初始化与网络接管（启动峰值单独记录）
initialization = struct();
initialization.Co = cfg.Co;
initialization.currentMax = cfg.currentMax;
initialization.currentMin = cfg.currentMin;
initialization.Qx = cfg.Qx;
initialization.N = cfg.N;
initialization.blockTo = cfg.blockTo;
initialization.dutyMin = cfg.dutyMin;
initialization.dutyMax = cfg.dutyMax;
initialization.explicitInitialVoltageDomain = cfg.explicitInitialVoltageDomain;
initialization.warmupDuty = [0.3612; 0.2044];
initialization.startupRamp = 0.08;
initialization.warmup = 0.12;
initialization.modelFile = fullfile(codeDir, 'models', 'identified_model.mat');
initialization.tag = 'C220_N20_localQuery';
initialization.controllerDir = codeDir;
initialization.nnVoltageDomain = cfg.nnVoltageDomain;
initialization.nnCurrentDomain = cfg.nnCurrentDomain;

