> 历史专题资料：文内原“下一步”只记录当时安排，不作为当前顺序。当前按开始这里.md与项目记忆与进度.md逐模式推进。

# 10：原项目怎样用EMPC训练神经网络

上一课的结果是一个已有函数：输入iL、Vo，返回占空比d。这一课继续沿作者的脚本走，不重新采集或训练。

**训练网络，就是让另一个计算函数学会模仿EMPC的答案。**

## 1. train_sample.m：向EMPC问很多次

原脚本依次扫描：

```text
电流：0、0.4、0.8……92A
电压：0、0.4、0.8……200V
```

每一对状态都调用：

```matlab
[da,region] = Bstep_controller10([iLa;Voa]);
```

这是查控制函数，不是逐点运行电路仿真。用C逻辑理解：

```c
for (int v = 0; v <= 500; ++v) {
    for (int i = 0; i <= 230; ++i) {
        float il = i*0.4f;
        float vo = v*0.4f;
        float duty = empc_control(il, vo);
        if (!isnan(duty)) {
            save_row(il, vo, feature, 200, duty);
        }
    }
}
```

共有115731个候选点。原脚本实际先保存所有结果，再删除含NaN的行；找不到EMPC可行区域的点不作为正常占空比标签。

最后的表：

| 第1列 | 第2列 | 第3列 | 第4列 | 第5列 |
|---|---|---|---|---|
| iL | Vo | 负载相关特征 | Vref | EMPC的d |

当前脚本第三列固定1，第四列固定200，保存为`shu200`。这是脚本目前的设置，不代表所有历史标签都用同一个特征值。

## 2. zhenghe.m：把不同工况的标签放到一起

原脚本依次加载`shu300、shu150、shu200`，拼成`changeR1`。

意图是让一张训练表包含不同负载工况的控制答案。可以理解为：

```c
// 概念：把多组工况样本放进同一个训练数组。
append(samples, labels_case_300);
append(samples, labels_case_150);
append(samples, labels_case_200);
```

原脚本采用硬编码行号拼接。我们当前先理解这条原流程，不另造数据填补文件。合并表并不保证网络在线一定能区分工况，还要看有效输入和训练配置。

## 3. myguiyihua.m：告诉网络“输入什么，学哪个答案”

原代码：

```matlab
load('changeR1.mat');
rowrank = randperm(size(changeR1,1));
a1 = changeR1(rowrank,:);
inputn  = a1(:,1:4)';
outputn = a1(:,5)';
```

`randperm`打乱样本顺序，仍然整行移动，输入与答案不会拆散。

输入是前4列，目标答案是第5列占空比。转置`'`是因为该MATLAB网络接口把“每一列”当成一个样本。

你熟悉的C记录可以写成：

```c
typedef struct {
    float il, vo, feature, vref;  // 输入
    float duty_empc;             // 想让网络学会的答案
} TrainingSample;
```

这里没有下一步电流或下一步电压。这个网络是在学控制律，预测电路的A、B已经在上游用过。

## 4. 创建网络，再调整权重

原代码：

```matlab
hiddennum = 8;
net = newff(inputn,outputn,hiddennum, ...
            {'tansig','tansig'},'trainlm');
net.trainParam.epochs = 3000;
net.trainParam.goal = 1e-8;
net = train(net,inputn,outputn);
```

`hiddennum=8`是这个脚本设置的隐层节点数；`tansig`是节点计算里的非线性函数；`trainlm`是训练时使用的Levenberg–Marquardt方法。

训练过程可以先这样理解：

```text
用当前权重算网络占空比
         ↓
与EMPC标签比较，得到误差
         ↓
训练算法调整权重和偏置
         ↓
再算、再比较，直到满足停止条件
```

`epochs=3000`是最大训练轮数，可能提前停止；`goal=1e-8`是误差目标，不保证一定达到。脚本另写了`lr`字段，不能据此把trainlm理解为普通固定学习率的梯度下降。

**训练完成后，保存的主要成果是权重和偏置。在线控制时不再调整它们。**

## 5. 检查输出，再生成Simulink模块

```matlab
an = sim(net,input_test);
error = an - output_test;
gensim(net);
```

这里`sim(net,...)`调用的是网络推理，不是重新运行功率电路。`an`是网络给出的占空比，`output_test`是对应的EMPC标签。

例如只用于说明误差含义：EMPC给0.80，网络给0.79，差为−0.01，即占空比相差1个百分点。

- MAE：平均绝对误差。
- RMSE：均方根误差，较大的误差会更显著地影响结果。
- 最大误差：检查最差的点，不能只看平均值。

`gensim(net)`生成可放进Simulink的网络模块。接到原PWM输入后，它就承担在线计算占空比的任务。

**原脚本的外部测试子集取自传给train的同一总表，尚不能视为独立测试。** 当前先按已有结果理解执行链，后续论文验证时要区分训练误差与独立测试误差。

## 6. 我们现在实际运行的是作者已经保存的网络

原SISO模型有效网络模块是`shu150和shu300以及变载`。当前已核对：

- 外部4个输入经过预处理后，只保留iL、Vo。
- 保存的有效结构是`2 → 40 → 1`。
- 在线输出占空比，再由PWM控制S1、S2。

所以当前在线可以先理解为：

```c
float duty = saved_network(il, vo);
set_pwm_duty(duty);
```

这里用的是项目已保存的网络，不是本课重新训练出的网络。独立训练脚本写8节点，模型保存40节点。第13课整理时进一步确认，原汇总TXT还保存了40节点、shu150单表训练的配置线索；其数据范围与原网络更接近。两套脚本应分别理解，尚未确认哪套配置能原样重建当前权重。当前先运行已有网络，不展开另做实验。

## 7. 一句话串起来

> 作者先查询EMPC，得到大量“状态—占空比”样本，再让网络拟合这些答案，最后把训练好的网络放进Simulink，在线根据采样状态计算占空比。

自查：

- [ ] 知道占空比标签来自EMPC，不是人工随便填写。
- [ ] 知道训练改变权重，在线推理使用固定权重。
- [ ] 知道网络输出的是d，不是下一步电压。

下一课拆开已经保存的网络，用C逻辑说明：输入归一化、40个节点计算、输出还原，怎样一步步得到占空比。

[原标签生成脚本](D:/Project/NN_EMPC_TPC/我们的科研工作区/主线工程/02_仿真工程/01_SISO_VsVo/模型与算法/代码/train_sample.m) · [原训练脚本](D:/Project/NN_EMPC_TPC/我们的科研工作区/主线工程/02_仿真工程/01_SISO_VsVo/模型与算法/代码/myguiyihua.m)
