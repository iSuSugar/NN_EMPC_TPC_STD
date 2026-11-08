# 48 / 72 / 120 V，220 µF，16→8轻量化网络工程

本轮五个独立模式已重新训练为16→8，并完成五独立模式及四类切换实际开关电路验证。九工况稳压：全部通过；最大平台稳态误差0.06568%。这不是训练达到1e-8或硬件验收的声明。

64→32 基准已归档，供历史对照。[64→32 历史基线](D:/Project/fpga_历史工程_20261103/20261104_正式基线整理/仿真/48_72_120_C220)
单输出网络225参数，DISO双输出网络234参数。电路、辨识、EMPC教师和训练标签沿用原条件。

## 先看这两份说明

* [16→8验收结果](16_8验收结果.md)：九工况误差、事件指标、与64→32比较及训练误差。
* [运行与模式切换说明](16_8运行与模式切换说明.md)：手动步骤、网络来源、输出头和切换时间轴。

## 平时怎么用

进入某个工况code目录，运行show_results只看已保存的两张图；运行run_closed_loop才重新仿真。当前已完成，不必为了查看结果重新训练。

只改网络结构时，在五个独立模式parameters改hiddenSizes，再各自myguiyihua、run_closed_loop。切换工况直接run_closed_loop，读取本目录内组成模式的新网络，不再训练一套切换网络。

完整重走五网络训练与九电路验证：

```matlab
% 当前目录先切到克隆所得仓库根目录
cd('48_72_120_C220_16_8');
run_all_modes('train');
run_all_modes('closed');
```

不要使用run_all去无谓重做辨识、EMPC和标签。五个独立网络都完成后再跑切换；原有模型已打开时，先处理自己的未保存修改并关闭同名模型。

## 当前副本的验证资料

各工况的已保存结果位于对应 `code/results`。其中 `NN_validation.json` 记录训练结果，`NN_native_trajectory.json` 和 `switching_dynamic.json` 记录轨迹和电路验证指标。九工况汇总见上面的《16→8验收结果》。本副本可用的验收证据以这些现存文件为准。

FPGA 工程入口、已交付的 bit 及各模式移植状态见验收顺序。[BX71 验收顺序](D:/Project/fpga_project/验证顺序.md)

仍需MATLAB、Simulink、电力系统模块库和MPT环境；模板在各工况自己的circuit/template。尚未由本轮完成多种子全模式消融、定点量化、ADC与计算延迟、FPGA资源/时序及实物验证。

## 运行配置与验收资料
正式入口读取 config/target_cases.json 与 config/switch_cases.json；各工况实际参数以自己的 code/parameters.m 为准。批量运行状态写入 results/run_status.json。
正式训练、仿真与绘图不依赖validation。仓库内config保留运行配置，code/results保留当前结果；历史核查目录不随本次上传补造。