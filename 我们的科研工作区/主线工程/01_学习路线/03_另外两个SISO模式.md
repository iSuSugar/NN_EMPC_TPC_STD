> 历史专题资料：文内原“下一步”只记录当时安排，不作为当前顺序。当前按开始这里.md与项目记忆与进度.md逐模式推进。

# 03：另外两个SISO模式

你已经掌握Vs→Vo的两阶段储能/放能。现在只改变供电和受电的端口，仍用电感伏秒平衡推导。以下均按理想器件、连续电流、周期稳态及Vo>VB>Vs分析。

## 1. VB→Vo：电池给负载供电

### a：S2、S3导通，S1关断

![VB到Vo储能](D:/Project/NN_EMPC_TPC/我们的科研工作区/主线工程/01_学习路线/images/03_SISO_VBVo_a.png)

路径：**VB正端 → S2 → L → S3 → VB负端**。电池给电感储能，Co给负载供电。

$$v_L=V_B,\qquad \frac{di_L}{dt}=\frac{V_B}{L}>0.$$

### b：S2保持导通，S1、S3关断

![VB到Vo放能](D:/Project/NN_EMPC_TPC/我们的科研工作区/主线工程/01_学习路线/images/04_SISO_VBVo_b.png)

路径沿一个回路读：**L下端 → 输出支路 → D3 → VB → S2 → L上端**。这次放能时电池仍在回路中：电池和电感一起向输出供能。

$$v_L=V_B-V_o,\qquad \frac{di_L}{dt}=\frac{V_B-V_o}{L}<0.$$

这就是它与上一课Vs→Vo的关键区别：上一课放能时电源不在供能回路中，电感电压是−Vo；这里是VB−Vo。

稳态伏秒平衡：

$$DV_B+(1-D)(V_B-V_o)=0.$$

由电感电压关系可写出一个周期的电流变化：

$$\Delta i_L=\frac{V_B}{L}DT_s+\frac{V_B-V_o}{L}(1-D)T_s=0.$$

消去Ts/L后得到上式。逐项展开为 $DV_B+V_B-DV_B-V_o+DV_o=0$，即 $V_B-(1-D)V_o=0$，所以：

$$\boxed{\frac{V_o}{V_B}=\frac1{1-D}},\qquad D=1-\frac{V_B}{V_o}.$$

72V升到200V，理想占空比D=0.64。100kHz下，储能6.4μs、放能3.6μs。这是Boost关系。

概念控制逻辑（不是完整驱动固件）：

```c
S1 = OFF;
S2 = ON;             // 两个阶段均保持导通
S3 = pwm(duty);      // 只有S3在两阶段之间切换
```

原毕业论文图2-4(b)正文及图注有开关编号互相矛盾的问题。这里依据电流通路和你的新版图，采用S2导通、S1/S3关断；之后还要核对对应Simulink实际门极接线，不照抄错号。

## 2. Vs→VB：电源给电池充电

独立Vs→VB模式按负载不参与供电分析；如果还同时给Vo供电，就进入SIDO。

### a：S1、S2导通，S3关断

![Vs到VB储能](D:/Project/NN_EMPC_TPC/我们的科研工作区/主线工程/01_学习路线/images/05_SISO_VsVB_a.png)

路径：**Vs正端 → D1 → S2 → L → S1 → Vs负端**。与Vs→Vo的储能阶段一样。

$$v_L=V_s,\qquad \frac{di_L}{dt}=\frac{V_s}{L}>0.$$

### b：S1保持导通，S2、S3关断

![Vs到VB放能](D:/Project/NN_EMPC_TPC/我们的科研工作区/主线工程/01_学习路线/images/06_SISO_VsVB_b.png)

路径：**Vs正端 → D1 → VB正端 → VB负端 → D2 → L → S1 → Vs负端**。

电源和电感一起给电池送能，电流进入电池正端，因此电池处于充电方向。

$$v_L=V_s-V_B,\qquad \frac{di_L}{dt}=\frac{V_s-V_B}{L}<0.$$

伏秒平衡：

$$DV_s+(1-D)(V_s-V_B)=0.$$

所以：

$$\boxed{\frac{V_B}{V_s}=\frac1{1-D}},\qquad D=1-\frac{V_s}{V_B}.$$

48V给72V电池充电，理想D=1/3；100kHz下，储能约3.33μs、放能约6.67μs。这也是Boost关系。

```c
S1 = ON;             // 两个阶段均保持导通
S2 = pwm(duty);      // S2切换
S3 = OFF;
```

这里的公式只说明理想稳态电压关系。真实电池充电还需要限流、合适的充电策略和保护，不能仅设置D=1/3就当成完整充电控制。

## 3. 三个SISO放在一起记

| 模式 | 储能时电感电压 | 放能时电感电压 | 理想电压关系 | 开关逻辑 |
|---|---|---|---|---|
| Vs→Vo | Vs | −Vo | Vo/Vs=D/(1−D) | S1、S2一起PWM，S3关 |
| VB→Vo | VB | VB−Vo | Vo/VB=1/(1−D) | S2常开、S3 PWM，S1关 |
| Vs→VB | Vs | Vs−VB | VB/Vs=1/(1−D) | S1常开、S2 PWM，S3关 |

表中“常开”表示始终导通。不要死记名称，**看放能阶段输入源是否仍在回路中**，就能解释为什么前一种是Buck-Boost关系，后两种是Boost关系。

## 4. 下一步

按顺序运行并解释对应的VB→Vo、Vs→VB仿真，重点核对S2/S3和S1/S2的门极逻辑，再进入SIDO。两模式本轮仅完成图解与推导，尚未运行对应仿真。

本课对照原毕业论文第2章图2-4、图2-5与式(2-2)、式(2-3)，以及用户新版Visio图和公式LaTeX源码第31～71式。Visio源图只读导出，哈希记录为images/visio_siso_remaining_sources.csv。
