# private文件逐项说明与电路读图

## 先答五个问题

### 1. 为什么原来清楚，现在电路图乱？

原来的功率电路已经画好。此前代码把网络、四输入采样、初始化、限幅、端口记录和多组To Workspace全部加到同一顶层，而且没有在添加后重新分层整理。很多模块默认叠在一起，记录信号横穿整个电路。这是新增模块的布局问题，需要修正。

现在保存的电路把新增模块分为两块：

* `TPC_Controller`：测量特征、采样保持、网络、初始化选择和占空比限幅。双击查看算法。
* `TPC_Logging`：波形记录、端口电流和开关门极记录。它观察信号，不输出控制命令。

功率电路继续使用原来的元件和电气连接。顶层的`Sxx_...`标签是Goto/From：同名标签表示同一根信号线，只是把长线改为标签表达。它们不产生延迟、不做数值计算；电气连接线没有用标签替代。`iL`、`V`、`Io`分别表示电感电流、受控电压和负载电流；`C1/C2/C3`表示Controller对应端口，不代表三个独立占空比。

例如48→120 V的Controller有三个输出用于不同用途：`Raw_network`是限幅前网络输出，`Sampled_features`是供日志记录的输入特征，`Applied_d1`才是初始化选择及限幅后实际送PWM的命令。网络仍只有一个独立占空比输出。

默认先读顶层的功率级，然后看Controller，最后需要追溯数据时才看Logging。不要把Logging里的众多输入误认为控制器需要那么多输入。

在某工况code目录运行：

```matlab
organize_circuit;       % 整理已保存电路并打开闭环模型，不训练、不重仿真
% organize_circuit(false); % 只整理并保存
```

已经完成整理的模型可以直接在circuit目录双击打开。若MATLAB里还开着旧版本，先确认自己的修改是否需要保存，再关闭旧标签并重新打开磁盘文件；organize_circuit遇到同名已打开模型会停止，避免覆盖你的未保存修改。

### 2. 电路是不是完全由代码生成？

分两部分：

1. **功率级来自项目内保存的SLX模板**：电源、MOSFET、二极管、电感、电容和负载连接原本已存在。代码复制该模板，设置本工况的电压、L/C、负载等参数。
2. **控制和测量由代码搭建**：插入训练好的网络权重、采样保持、初始化选择、限幅及日志模块，再连接到原PWM入口。

所以不是根据一个公式临时“猜画”功率电路。你可以在Simulink里逐块打开看参数、信号和连接。代码构建便于九个工况一致地重做；生成的SLX仍是可以展开的模型。

要保留手工修改，应先另存一个研究版本；直接修改自动生成的CLOSED模型，下次run_closed_loop重建时会被模板和代码重新生成。正式修改物理参数用parameters，正式修改拓扑用本工况模板，正式修改控制连接用构建代码，并重新验证。

### 3. private是什么？我需要自己挨个运行吗？

private是MATLAB的私有函数目录：同一code目录中的主函数可以调用它。你通常运行EMPC1、run_closed_loop等入口，不在命令窗口逐个运行private函数。它们承担具体辅助工作，不是另外一套隐藏控制算法。

例如：

```text
run_closed_loop
  ├─ parameters：读参数
  ├─ tpc_make_plant：复制本地模板并接入网络
  │    ├─ tpc_add_relu_block：网络矩阵变成Simulink模块
  │    ├─ tpc_add_port_trace：增加记录
  │    ├─ tpc_clean_root：删除已废弃模块并处理未用端口
  │    └─ tpc_assert_topology：核对功率连接
  ├─ sim：运行开关电路
  ├─ tpc_response_metrics / tpc_port_metrics：计算指标
  ├─ tpc_verify_candidate_nn：同一真实状态上查EMPC和网络
  ├─ tpc_readable_layout：整理将要保存的电路显示
  └─ tpc_publication_figures / tpc_show_figures：保存和显示图
```

### 4. cfg.source原来依赖什么？现在怎样独立？

cfg.source是一个SLX文件路径。以前它指向工程外的ICPRE旧目录，构建时load_system读取它，然后save_system另存成本工况电路。旧目录移动或删除后，重新辨识、生成闭环或生成切换电路就可能失败。这种运行依赖此前确实存在。

现在每个工况自带（模板沿用原文件名，其中Vo200是历史命名；实际120 V、220 µF条件由parameters和构建过程设置）：

```text
工况/
  circuit/
    template/原模型文件名.slx     ← 本工况自己的模板
    TPC_..._CLOSED.slx            ← 生成后的可运行闭环模型
  code/
    parameters.m
```

parameters中现在写的是：

```matlab
cfg.source = fullfile(fileparts(codeDir), 'circuit', 'template', '本工况模板名.slx');
```

fileparts(codeDir)就是本工况目录。路径随本工程位置计算；不是去旧ICPRE目录找文件。九份模板复制时核对了SHA256，内容与来源一致。原始来源只作为历史追溯记录，不再是当前构建所需路径。不要随意删除本地template文件夹。

独立的含义是：不再运行依赖旧ICPRE目录或470 µF工程。仍需要MATLAB、Simulink、相应电力系统模块库，以及设计EMPC所需MPT等工具箱。切换模式仍使用**本工程内**对应独立模式的网络，这是工程内部依赖。

原Python拓扑检查改为MATLAB原生的tpc_assert_topology，不再要求代码里那个个人用户目录下的Python解释器。过去的.py与configuration_snapshot归档到validation/history，供追溯，不参与当前运行。

### 5. EMPC两个输入、网络四个输入，到底怎么回事？

先把“状态”和“电路控制输入”区分清楚：电路状态是`x=[iL;Vo]`；电路控制输入是占空比u。查EMPC函数时把两个状态传进去，因此口头会说“EMPC两个输入”。这不是说电路有两个占空比；DISO的占空比输出数才是两个。

以120 V、48 Ω和96 Ω为例：

```text
EMPC_48Ω：提前固定R=48Ω、Vref=120V
查询 [iL;Vo] → d48

EMPC_96Ω：提前固定R=96Ω、Vref=120V
查询 [iL;Vo] → d96

合并标签训练一个网络：
[iL;Vo;负载电流特征;Vref] → d
```

同样iL、Vo下，不同负载可能需要不同d。单个固定工况EMPC已经“知道”自己对应哪个负载；合并后的网络需要负载信息，不能只拿两个状态区分。

标签里第三项主要按`Vo/R`构造，并加小扰动增强；实际电路第三项来自对应电流测量。因此在Vo=120 V时：

| 工况 | 前两项可能相同 | 第三项 | 第四项 |
|---|---|---:|---:|
| 48 Ω | iL、Vo | 2.5 A附近 | 120 V |
| 96 Ω | iL、Vo | 1.25 A附近 | 120 V |

网络据此区分负载工况。它不是精确地在内部运行一个EMPC选择开关，而是用数据学习这些标签的关系。

**第四项目前在各固定参考工况数据中是常数**：例如这个模式都是120 V。保留第四项是当前统一接口，但这次训练没有证明任意参考电压都能正确跟踪。一个只在120 V训练的网络，不能仅把第四项改成100 V就宣布能用。常量输入归一化时可能被赋予零增益，应以保存的net为准。

类似地，用48、96 Ω两个负载训练并通过相应扰动验证，不等于已经验证所有电阻、恒功率负载或所有输入电压。

## private文件逐项说明

每项按“谁用它—接收什么—做什么—学习时看哪里”解释。除明确提到的主入口外，下面函数均由主流程调用。

### A. 参数、路径与缓存

**tpc_load_case.m**

主流程与绘图、切换索引读取调用。输入是code目录；在独立函数工作区运行parameters，返回cfg及需要时的initialization。它解决的是参数读取和MATLAB工作区问题，不进行控制计算。你改参数仍改parameters，不在这里重复写参数。

**tpc_project_root.m**

根据当前函数位置向上定位含run_all_modes和EMPC_LOOP的工程根目录。用于跨模式读取与路径拼接。搬项目时比写死D盘路径稳妥；内部目录结构仍要保留。

**tpc_read_cases.m**

读取validation中的模式索引JSON，再用各模式当前parameters补充/覆盖参数并组装codeDir、caseDir。切换工况借它找到各独立模式。索引负责列出模式，日常数值参数以parameters为准。

**tpc_cfg_signature.m**

EMPC缓存检查使用。把配置整理成签名，排除位置类字段；模板按本工程内副本的内容校验，而不是把旧绝对路径当作算法变化。用于判断已有控制器是否对应当前模型/配置。不要为了跳过重新设计而删除签名检查。

**tpc_fingerprint.m**

对显式输入求SHA256。EMPC1把配置、模型与参考值组合起来生成指纹。它不评价控制器效果，只辨别“输入条件有没有变”。

### B. 电路构建与采集

**tpc_make_plant.m**

model_calculate、初步采集、run_closed_loop调用。输入cfg、负载、open/closed以及闭环时的net；返回加载后的模型名称。复制本地模板，设置电源、L/C、负载和PWM频率，再添加控制、四输入和记录模块。理解代码搭电路，优先看这个文件。

**tpc_collect_continuous.m**

辨识阶段需要初步工作点校准时调用。输入cfg和保存文件路径；先运行一段稳定过程，再改变各独立占空比，保存连续数据与稳态锚点。它不是网络训练，也不是最终闭环验收。

**tpc_add_relu_block.m**

电路构建和切换构建调用。输入模型名、子系统名和net参数；创建InputScale、InputShift、各层Weights/Bias、隐藏层ReLU和线性输出。打开Controller中的TPC_NN，看到的就是它搭建的矩阵计算。这是与以后硬件实现直接相关的文件。

**tpc_clean_root.m**

构建阶段调用。沿原电气元件和有效控制信号保留所需模块，删除被替换后遗留的旧网络/示波器等；给未用输出接Terminator，必要时给悬空MOSFET控制口接关闭命令。它会操作模型，因此不要当通用清理工具对任意模型手动运行。

**tpc_add_port_trace.m**

闭环构建调用。观察已有端口电流与实际MOSFET门极，添加数据类型转换、Mux、To Workspace和Scope，并保存通道名称元数据。不在功率回路里新增串联电阻或改变拓扑。实际门极记录能解释DISO跨段后的有效导通与命令占空比差别。

**tpc_assert_topology.m**

构建时输入模板SLX与候选SLX。用MATLAB解包SLX、读取XML，比较顶层功率连接端口构成的电气节点；不一致就停止。它验证连接，并不证明元件参数、控制算法、硬件耐压都正确，这些由其他检查负责。

**tpc_readable_layout.m**

闭环仿真读完结果、保存模型之前调用，也由organize_circuit调用。把新增控制与记录分层，使用同名Goto/From减少长信号线，整理子系统内部显示。它不改网络权重、控制周期或功率级物理连接；布局修改后另做前后输出比较。

### C. 控制计算与数值核对

**tpc_current_weight.m**

EMPC1使用。根据cfg和负载返回电流代价权重，支持个别模式按负载配置不同权重。它不是在线电流限幅；权重与最大允许电流是两个不同参数。

**tpc_nn_predict.m**

训练评估与实际轨迹对照使用。输入net以及一列或多列物理特征；输出限幅前网络占空比。核心是输入缩放、矩阵乘加和ReLU。当前两隐藏层网络对应：

```matlab
z  = net.inputGain .* s + net.inputShift;
h1 = max(0, net.W1*z  + net.b1);
h2 = max(0, net.W2*h1 + net.b2);
u  = net.W3*h2 + net.b3;
```

文件还保留可选历史输入变换分支；是否使用取决于net字段，不能自行把分支套到当前网络。部署时严格依照保存网络的数据和变换。

**tpc_verify_candidate_nn.m**

run_closed_loop在完成电路仿真后调用。读取真实采样特征，计算网络输出，同时为这些相同状态查询相应负载的EMPC，输出RMSE、最大差和原生网络重放一致性。它不是再次闭环仿真，也不是拿理想电流替换实测电流。

**tpc_run_mode_entry.m**

切换工况的前几步使用。临时进入指定独立模式目录执行对应入口，完成后恢复原目录。用途是复用本工程内已设计的模式控制器；不从ICPRE旧目录借用已训练网络。

### D. 结果指标与显示

**tpc_response_metrics.m**

闭环和切换验证调用。输入时间、波形、参考和事件时刻；输出稳态平台误差、电压范围、电流峰值、恢复时间等report字段。启动统计、反馈窗口统计、周期平均值与原始开关波形各有范围，解释报告时必须保留这些定义。

**tpc_port_metrics.m**

接收端口轨迹、通道名称元数据和cfg，计算各平台端口电流、功率方向、门极有效导通等。判断SIDO是否向两个端口送能、DISO是否两个输入共同供能时需要它；仅看120 V稳住还不够。

**tpc_publication_figures.m**

读取保存的辨识、EMPC、网络和闭环证据，生成对应分析图及FIG/PNG/PDF。不负责训练网络，也不改变控制结果。完整详细图放results/figures，默认显示仍保持两张。

**tpc_export_figure_pdf.m**

供绘图函数使用，将已建立的图导出PDF。只影响文档图件，不参与电路运算。

**tpc_show_figures.m**

show_results、show_all_results及各阶段结束时调用。读取已保存图并按summary/all等方式显示。只看结果先用show_results，不必运行完整训练。

### 历史文件

旧的`tpc_check_topology.py`是同一电气连接比较的Python实现，已退出运行流程。旧configuration_snapshot也不再放在日常private中；两者归档到validation/history。当前说明以实际在用的.m文件为准。

## 建议实际读图的一次顺序

1. 打开48→120 V的CLOSED模型，先找到电源、电感、输出电容、负载；这些是能量路径。
2. 沿电感电流、电压和负载电流测量找到同名SIG标签，再找进入Controller的标签；这些是信息路径。
3. 双击Controller，找到四输入Mux：三个实测量和一个参考常量。采样保持后一起进入TPC_NN。
4. 双击TPC_NN，看到缩放、偏置、三个权重矩阵和两个ReLU；它们与net文件的字段一一对应。
5. 返回Controller，看初始化Switch：启动阶段选初始化命令，接管后选网络输出；随后限幅，再送PWM。
6. 回到顶层看PWM到门极的原控制连接；最后需要查数据时再打开Logging。

能讲清这六步，比一开始背下所有辅助函数更重要。
