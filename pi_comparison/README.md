# 48 72 120 V PI与NN EMPC对比

本目录在正式`48_72_120_C220_16_8`的电路副本上比较五种单模式和四组往返切换。正式参数、网络和既有结果不覆盖，不进行网络训练。

## 看结果

先看[Word对比文档](report/48_72_120_PI与NN_EMPC仿真对比.docx)或[网页阅读版](report/48_72_120_PI与NN_EMPC仿真对比.md)，数字见`comparison_metrics.csv`，必要曲线在`figures`。36行事件数据对应9工况×2控制器×2事件。

每组曲线采用完整PWM周期均值。恢复带是后平台均值±0.1 V、评价窗口最多3 ms，稳态误差另列。初始化阶段不参与主要比较。图不是实物波形。

## 怎么运行

MATLAB当前目录先切到克隆所得仓库根目录：

```matlab
cd('pi_comparison');
run_comparison('plots');  % 读取已保存数据并重绘
% run_comparison('single'); % 需要时运行五种单模式
% run_comparison('switch'); % 需要时运行四组切换
% run_comparison('design'); % 明确需要重新设计PI时才执行
```

已有本次结果会复用。改变参数或控制代码后，应把本目录旧results归档到仓库外，再生成新结果；不可把新PI参数与旧仿真结果混用。首次从零运行`run_comparison('all')`需要MATLAB、Simulink、电力系统模块和Control System Toolbox；报告Word生成需要Python及python-docx。

`build_report.py`从汇总JSON和图生成Word与Markdown，不启动MATLAB。生成Word后仍应渲染并检查排版。

## 代码与数据

| 文件 | 用途 |
|---|---|
| audit_pi.m 与 audit.json | 读取正式工况、模型与初始化设置 |
| design_pi.m 与 pi_design.json | 在辨识模型上整定双环PI并冻结参数 |
| tuning_*.json | 所有通过双负载稳定性筛选的候选参数 |
| run_pi_cases.m | 从同一正式电路复制PI与NN副本，独立运行并统计 |
| pi_controller_template.txt | 电压外环、电流内环、限幅及抗积分饱和 |
| private/pi_install_switch.m | 按模式调度启停对应PI，DISO输出按固定向量分配 |
| verify_pi_comparison.m | 检查两种控制器电气参数、连接、时序和限幅一致 |
| plot_pi_comparison.m | 生成九组必要图、汇总JSON与CSV |
| results/工况/PI.mat 与 NN.mat | 全程周期均值、事件局部原始数据及配置 |
| results/工况/CMP_*.slx | 独立对比电路；不是正式电路的替代版本 |

## 比较边界

PI使用电压和电感电流反馈；NN还输入实际负载电流。本轮没有额外PI负载前馈对照，不能把全部动态差异归因于预测机制。DISO的PI沿满载辨识模型电流增益方向分配两个占空比，没有单独设计电池功率分配闭环。

切换模型保留原辅助功率路径；它不是已验证的三MOS实物热切换实现。这里的仿真对比不能替代输入电压扰动、参数失配、量化和硬件执行时间测试。
