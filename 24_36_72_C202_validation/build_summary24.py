"""Build a repository report from actual completed switching simulations."""
from pathlib import Path
import json,csv,hashlib,subprocess,math

r=Path(__file__).resolve().parent
ref=json.loads((r/'experiment_reference.json').read_text(encoding='utf-8'))
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def f(x,n=3):return '未在窗口内恢复' if x is None or not math.isfinite(x) else f'{x:.{n}f}'
lines=['# 24 V输入 72 V闭环与电感电流核对','',
'本轮按用户2026年11月14日确认的110 µH、输出电容实测202 µF建模，另比较220 µF。输入Vs24 V、Vb36 V；Vs→Vo闭环目标72 V，Vs→Vb受控端目标36 V。原48/72/120和12/18/32工程、网络与FPGA程序不修改。','',
'## 先看结论','',
'24 V到72 V的独立双环PI在本模型中可以闭环，0.5/1 A两负载稳态均处于CCM。这只是仿真可行性，不表示PPT电流测量已经校准通过，也不是24 V新NN或FPGA闭环已完成。旧48 V网络不用于24 V闭环。','',
'## 72 V闭环电感电流','',
'| 输出电容 | 脉宽代理增量 | 负载 A | 平均输出 V | 电感均值 A | 电感RMS A | 谷值 A | 峰值 A | 每周期纹波 A | CCM周期比例 |',
'|---|---|---|---|---|---|---|---|---|---|']
closed=[]
for p in sorted((r/'results/closed72').glob('*.json')):
 q=read(p);closed.append(q)
 for load,a in zip([.5,1],q['plateaus'][:2]):
  lines.append('| '+' | '.join([f(q['C']*1e6,0)+' µF',f(q['controller']['dutyExtension']*1e7,0)+' ns',f(load,1),f(a['meanVoltage']),f(a['meanCurrent']),f(a['rmsCurrent']),f(a['minCurrent']),f(a['peakCurrent']),f(a['meanCycleRipple']),f(a['fractionCyclesAbove20mA']*100,0)+'%'])+' |')
lines += ['',
'闭环负载预设0.5 A并从启动起连接，低于5 V按比例降低吸收；60 ms升至1 A，80 ms回到0.5 A。开环对照另在30 ms接入负载，不把两者的启动过程混比。稳态窗口分别为55～59、75～79、85～89 ms；电压给定在20 ms内从0爬升到72 V。表中每个窗口保留原始开关纹波。CCM判定要求周期谷值大于20 mA；该数仅为数值判定容差，不是实物保护阈值。','',
'![202µF闭环](figures/closed_C202_delay0ns.png)','',
'![72V电感周期波形](figures/closed72_inductor.png)','',
'双环PI按理论CCM平均模型整定，电流环目标2 kHz、电压环300 Hz、目标相位裕度65°；积分采用前向欧拉和抗饱和。设计模型假定绕组电阻0.1 Ω，这不是实物测得值。电流参考限幅0～6 A，占空比命令0～0.85；参考限幅不等于逐周期过流保护，不能直接照此把现板上电。具体增益见各closed72/*.json的controller。','',
'当前控制采样10 µs，但尚未加入真实ADC采样相位、计算到下一PWM边界的更新延迟及定点量化；也没有非线性电感饱和或实物温升模型。110 µH为用户确认的小信号标称值，不能据本次固定L仿真排除饱和。','',
'“270 ns”是将PPT约2.7个百分点的高电平增量作为占空比偏置加入功率级的敏感性工况。它不是完整驱动动态模型，也不复现VGS/VDS振铃、米勒耦合或器件结温。PI能消除该静态偏置对稳态电压的影响，不说明驱动故障已修复。','',
'## 开环与PPT电压对照','',
'| 模式 | 负载 A | 命令占空比模型输出 V | VGS代理模型输出 V | PPT输出 V | VGS代理下电感均值 A | 纹波 A |',
'|---|---|---|---|---|---|---|']
opens=[]
for c in ref['cases']:
 a=read(r/f'results/{c["id"]}/open_command.json');b=read(r/f'results/{c["id"]}/open_vgs_proxy.json');opens.append((c,a,b))
 for k,load in enumerate([.5,1]):
  x=a['plateaus'][k];y=b['plateaus'][k]
  assert abs(x['actualLoadCurrent']-load)<.02 and abs(y['actualLoadCurrent']-load)<.02
  lines.append('| '+' | '.join([c['id'],f(load,1),f(x['meanVoltage']),f(y['meanVoltage']),f(c['VoMeasured_V'][k]),f(y['meanCurrent']),f(y['meanCycleRipple'])])+' |')
lines += ['',
'这些电路采用既有模板的器件模型与寄生参数，并没有用本次实物数据重新辨识。VGS代理比原命令更接近部分实测电压，但仍有明显偏差；未为了贴合PPT而修改L、损耗或电流倍率。模型电流只能作为应核对的预期量级，不能据此宣布实物电流正确。','',
'CC负载用受控电流源实现，低于5 V时按电压比例降低吸收电流，并有1 µs的电压记忆打断代数环。该下限和延迟是仿真假定，不是电子负载规格；真实设备的最低工作电压、启动延迟和动态需要查型号/实测。DISO原模板的负载切换支路单独隔离：将原负载置1 GΩ并在相同输出及电流传感器返回节点接CC负载，避免把原并联支路误当CC0.5 A。其余功率器件及门极调制保留。','',
'PPT有待澄清：VB→Vo表头Q2/Q3与既定映射相反，本模型仍用Q2常开、Q3调制；Vs→Vb比较的是电池端电压而非独立Vo；SIDO斜杠后的1.07 A/2.34 A含义未定，不拿它们当电感电流。DISO两路命令保留分段映射，不能把Q2复合门极占比当第三个独立输入。','',
'## CCM与轻载DCM','',
'| CC设定 A | 最后窗口输出 V | 电感谷值 A | 电感峰值 A | 近零样本比例 | CCM周期比例 |',
'|---|---|---|---|---|---|']
light=[]
for p in sorted((r/'results/ccm_boundary').glob('*.json')):
 q=read(p);light.append(q)
 lines.append('| '+' | '.join([f(q['setLoadCurrent'],1),f(q['meanVoltage']),f(q['minimumCurrent']),f(q['maximumCurrent']),f(q['fractionNearZero']*100,1)+'%',f(q['fractionCCMcyclesAbove20mA']*100,0)+'%'])+' |')
lines += ['',
'![导通模式](figures/CCM_DCM.png)','',
'这里固定占空比0.7522，不是72 V闭环。在本模型中0.1 A出现零电流区间，最后窗口输出约87 V且不代表已经收敛到稳态；0.2 A已进入CCM但接近边界，0.5 A的电流谷值有明显余量。不能把这组固定占空比结果当作真实电子负载安全下限。','',
'对于Vs→Vo的理想CCM估算：D=Vo/(Vs+Vo)=0.75；ΔiL≈Vs·D/(L·fs)=1.64 A；IL平均≈Io/(1−D)，故0.5 A输出约2 A、1 A约4 A，临界输出电流约(1−D)·ΔiL/2=0.205 A。器件压降、寄生参数及CC负载动态会改变实际边界，因此最终以完整周期谷值和零电流区间判定。','',
'CCM研究不表示只要负载不足就必然损坏。DCM可能改变开环增益并使轻载输出抬升；先前48 V损坏仍缺少故障前可信的电流零点、VDS/VGS峰值、负载投入状态和电感饱和数据，不能认定唯一原因。','',
'## 现在实物需要核对什么','',
'1. 电流探头消磁调零，确认正方向和A/V倍率，并保存无电流时的零线。PPT第4页的两幅图显示均值−8.44 A与约0.17 A、峰峰值约7.8/7.7 A；这些读数与当前模型量级不一致，不能直接采用。','2. 在24 V、已确认0.5 A及1 A负载下，各取连续至少3个稳态PWM周期，保存原始CSV；同步记录VGS、Vo及iL，并给出实际负载电流。','3. 比较电感上升/下降斜率、周期、谷值、平均值和峰峰值。若纹波确为6～8 A而非探头倍率/振铃统计，应检查实际电感在该偏置电流下的感量与饱和，而不是把电容202/220 µF差异当作全部解释。','4. 确认输出电压采样、电感电流采样、极性、延迟和保护后，再进入受控的低压闭环台架。这里的PI参数和6 A参考限幅不能当作现板已验收的保护设置。','5. 若要NN闭环，24 V/72 V必须建立新的模型、EMPC标签和训练验证；已有48 V或12 V网络没有因本次PI仿真而获得24 V适用性。','',
'## 工程入口','',
'```matlab',"% 当前目录先切到仓库根目录", "cd('24_36_72_C202_validation');", "show_results24;      % 仅打开闭环总览与电感周期图，不重跑", "show_results24(true);% 再加轻载CCM/DCM图", "% 以下只在需要重新仿真或绘图时执行", "run_open24;          % 读取缓存或运行五模式开环", "run_closed24;        % 202/220µF及两种脉宽敏感性PI闭环", "run_light24;         % 固定占空比的轻载CCM/DCM检查", "plot_results24;      % 用已保存数据绘图",'```','',
'已有MAT结果会复用；改变参数或代码后需先把旧results归档，再重新运行。原始事件波形和全程周期均值在results，表格在open_current_comparison.csv，实测参考条件在experiment_reference.json。本轮未改PPT、未训练NN、未生成/下载bit、未操作真实功率电路。','']
(r/'README.md').write_text('\n'.join(lines),encoding='utf-8')
assert len(opens)==5 and len(closed)==4 and len(light)==3
protected={}
for folder in ['48_72_120_C220_16_8','12_18_32_C220_16_8']:
 for p in (r.parent/folder).glob('EMPC_LOOP/*/code/models/net*.mat'):
  protected[p.relative_to(r.parent).as_posix()]=hashlib.sha256(p.read_bytes()).hexdigest()
audit={'date':'2026-11-14','scope':'24V source,36V battery,72V output,110uH,202uF with220uF sensitivity','openSwitchingRuns':10,'closedSwitchingRuns':4,'lightLoadRuns':3,'simulatedNotMeasured':True,'neuralTrainingRuns':0,'hardwareActions':0,'mainResult':'Independent PI simulation feasible; measured current calibration and model mismatch remain unresolved','networkHashesAtCompletion':protected}
(r/'execution24.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8')
print('REPORT24_COMPLETE',r/'README.md')
