"""Create the Chinese comparison report from completed experiment JSON and figures.
Requires python-docx. Run only after plot_pi_comparison and fairness verification.
"""
from pathlib import Path
import json, math
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.enum.text import WD_ALIGN_PARAGRAPH

HERE=Path(__file__).resolve().parent
S=json.loads((HERE/'comparison_summary.json').read_text(encoding='utf-8'))
P=json.loads((HERE/'pi_design.json').read_text(encoding='utf-8'))
F=json.loads((HERE/'fairness_verification.json').read_text(encoding='utf-8'))
assert len(S)==len(F)==9 and all(x['physicalParametersEqual'] and x['timingAndDutyLimitsEqual'] for x in F)
out=HERE/'report';out.mkdir(exist_ok=True)
doc=Document();sec=doc.sections[0]
sec.page_width=Inches(8.5);sec.page_height=Inches(11)
sec.top_margin=sec.bottom_margin=Inches(.68);sec.left_margin=sec.right_margin=Inches(.7)
for name in ['Normal','Title','Heading 1','Heading 2','Caption']:
 st=doc.styles[name];st.font.name='Times New Roman';st._element.rPr.rFonts.set(qn('w:eastAsia'),'宋体');st.font.color.rgb=RGBColor(0,0,0)
doc.styles['Normal'].font.size=Pt(11)
doc.styles['Normal'].paragraph_format.line_spacing=1.18
doc.styles['Normal'].paragraph_format.space_after=Pt(7)
doc.styles['Title'].font.size=Pt(20)
doc.styles['Heading 1'].font.size=Pt(15)
doc.styles['Heading 2'].font.size=Pt(12)
doc.styles['Caption'].font.size=Pt(10)
doc.styles['Caption'].font.bold=False
doc.styles['Caption'].font.italic=False
for nm in ['Heading 1','Heading 2']:doc.styles[nm].paragraph_format.space_before=Pt(10)
header=sec.header.paragraphs[0];header.text='三端口变换器  PI与NN–EMPC仿真对照';header.style=doc.styles['Caption']
footer=sec.footer.paragraphs[0];footer.alignment=WD_ALIGN_PARAGRAPH.CENTER
fld=OxmlElement('w:fldSimple');fld.set(qn('w:instr'),'PAGE');footer._p.append(fld)

def para(t):return doc.add_paragraph(t)
def heading(t):doc.add_heading(t,level=1)
def page(t):doc.add_page_break();heading(t)
def fmt(v,d=3):
 if v is None or (isinstance(v,float) and not math.isfinite(v)):return '未在窗口内恢复'
 return f'{v:.{d}f}'
def table(headers,rows,widths=None):
 t=doc.add_table(rows=1,cols=len(headers));t.autofit=False
 for c,h in zip(t.rows[0].cells,headers):c.text=h
 t.rows[0]._tr.get_or_add_trPr().append(OxmlElement('w:tblHeader'))
 for vals in rows:
  cells=t.add_row().cells
  for c,v in zip(cells,vals):c.text=str(v)
 for ri,row in enumerate(t.rows):
  pr=row._tr.get_or_add_trPr();pr.append(OxmlElement('w:cantSplit'))
  for i,c in enumerate(row.cells):
   if widths:c.width=Inches(widths[i])
   tcpr=c._tc.get_or_add_tcPr();mar=OxmlElement('w:tcMar')
   for side in ['top','bottom','left','right']:
    a=OxmlElement('w:'+side);a.set(qn('w:w'),'75');a.set(qn('w:type'),'dxa');mar.append(a)
   tcpr.append(mar)
   for p in c.paragraphs:
    p.paragraph_format.space_after=Pt(3);p.paragraph_format.line_spacing=1.05
    for r in p.runs:r.font.size=Pt(9.5);r.bold=ri==0
 borders=OxmlElement('w:tblBorders')
 for side in ['top','bottom','insideH']:
  e=OxmlElement('w:'+side);e.set(qn('w:val'),'single');e.set(qn('w:sz'),'4');e.set(qn('w:color'),'808080');borders.append(e)
 t._tbl.tblPr.append(borders)
 doc.add_paragraph().paragraph_format.space_after=Pt(1)
 return t
def maxr(s,c,key):return max(e[key] if e[key] is not None else math.inf for e in s[c]['events'])
def eq(parts):
 p=doc.add_paragraph();p.paragraph_format.space_after=Pt(6);o=OxmlElement('m:oMath')
 for text,sub in parts:
  if sub:
   q=OxmlElement('m:sSub');e=OxmlElement('m:e');r=OxmlElement('m:r');t=OxmlElement('m:t');t.text=text;r.append(t);e.append(r);q.append(e)
   e=OxmlElement('m:sub');r=OxmlElement('m:r');t=OxmlElement('m:t');t.text=sub;r.append(t);e.append(r);q.append(e);o.append(q)
  else:
   r=OxmlElement('m:r');t=OxmlElement('m:t');t.text=text;r.append(t);o.append(r)
 p._p.append(o)
def figure(s,n):
 p=doc.add_paragraph();p.paragraph_format.space_after=Pt(3);p.add_run().add_picture(str(HERE/s['figure']),width=Inches(7.05))
 p=doc.add_paragraph(f'图{n}  {s["title"]}的两次事件响应。蓝色实线为NN，橙色虚线为PI；两者均为完整PWM周期均值。',style='Caption')
 p.paragraph_format.space_after=Pt(10)

doc.add_paragraph('48 72 120 V三端口变换器\nPI与NN EMPC仿真对比',style='Title')
para('2026年11月8日  正式16–8网络  输出电容220 µF  独立对比记录')
nn_worst=max(s['NN']['maximumPlateauErrorPct'] for s in S);pi_worst=max(s['PI']['maximumPlateauErrorPct'] for s in S)
single_better=sum(maxr(s,'NN','peakDepartureV')<maxr(s,'PI','peakDepartureV') for s in S[:5])
switch_near=sum(abs(maxr(s,'NN','peakDepartureV')-maxr(s,'PI','peakDepartureV'))<=.01 for s in S[5:])
para(f'本轮在相同保存电路的独立副本上，重新运行五种单模式和四组往返切换，共18次实际开关电路仿真。五种单模式中，{single_better}种的最大变载电压偏差为NN更小；四组切换中，{switch_near}组的最大偏差差异不超过0.01 V。九工况最大平台稳态相对误差分别为NN {nn_worst:.4f}%、PI {pi_worst:.4f}%。该结果描述本次两种具体实现，不代表所有PI结构或整定的上限。')
heading('结果总览')
rows=[]
short=['Vs→Vo','Vb→Vo','Vs→Vb','SIDO','DISO','SIDO→SISO→SIDO','DISO→SISO→DISO','DISO→SIDO→DISO','SISO→SIDO→SISO']
for title,s in zip(short,S):
 rows.append([title,fmt(s['NN']['maximumPlateauErrorPct'],4)+' / '+fmt(s['PI']['maximumPlateauErrorPct'],4),fmt(maxr(s,'NN','peakDepartureV'))+' / '+fmt(maxr(s,'PI','peakDepartureV')),fmt(maxr(s,'NN','recoveryUs'),0)+' / '+fmt(maxr(s,'PI','recoveryUs'),0)])
table(['工况','最大平台误差 %\nNN / PI','最大事件偏差 V\nNN / PI','最长恢复 μs\nNN / PI'],rows,[1.8,1.9,1.7,1.65])
para('事件偏差相对事件前0.5 ms均值计算；恢复时间指进入事件后平台均值±0.1 V并保持至评价窗口结束，评价窗口最多3 ms。恢复带并非对120 V的绝对误差带，稳态误差另列。0表示首个事件后周期均值即满足该带，不表示物理瞬态为零；统计分辨率为10 µs。所有指标均排除声明的初始化区间。')

page('比较条件与PI结构')
para('双方采用相同功率元件、辅助切换路径、负载或模式事件、初始化命令、PWM与反馈采样时序。Vs→Vb受控端口为72 V、负载20/40 Ω；其余受控输出为120 V、负载48/96 Ω，模式切换固定48 Ω。电感110 µH，输出电容220 µF；开关频率100 kHz，控制采样周期10 µs。')
para('PI为离散电压外环和电感电流内环，积分采用前向欧拉。内环使用反算抗饱和，系数0.2；外环在电流参考或下游占空比受限且误差继续推动饱和时暂停积分。电流参考范围−0.02～18 A，占空比限幅沿用各模式原配置；这不是实物过流保护。')
eq([('e','v'),('[k] = ',None),('V','ref'),(' − ',None),('v','o'),('[k]',None)])
eq([('i','ref'),('[k] = sat(',None),('i','0'),(' + ',None),('K','pv'),(' ',None),('e','v'),('[k] + ',None),('z','v'),('[k])',None)])
eq([('q[k] = ',None),('K','pi'),(' (',None),('i','ref'),('[k] − ',None),('i','L'),('[k]) + ',None),('z','i'),('[k]',None)])
eq([('u[k] = sat(',None),('u','0'),(' + g q[k])',None)])
para('DISO的两路局部调制命令沿固定分配向量g变化，g由满载辨识模型B矩阵的电流行归一化得到；两个分量均独立限幅，并沿用原分段门极映射，不能将命令直接等同整周期门极占比。该PI方案未额外控制电池功率分配。切换时停用模式的积分状态复位，启用后由其固定参数接管；没有为每次事件重新整定。')
g=next(p['direction'] for p in P if p['id']=='DISO')
para(f'DISO本轮g = [{g[0]:.6f}, {g[1]:.6f}]ᵀ，分别对应原模型两路独立调制命令。')
rows=[]
for p in P:rows.append([p['id'],fmt(p['KpV'],5),fmt(p['KiV'],2),fmt(p['KpI'],6),fmt(p['KiI'],2)])
table(['模式','外环Kp','外环Ki','内环Kp','内环Ki'],rows,[1.8,1.3,1.3,1.3,1.35])
para('外环Kp、Ki的单位分别为A/V、A/(V·s)，内环分别为1/A、1/(A·s)。单模式i₀取半载模型稳态电流，u₀取原初始化命令；切换工况两者取48 Ω对应模式的稳态锚点。')
para('本轮模型和稳态锚点均来自既有仿真数据，并非实物辨识。通过pidtune以60°相位裕度为目标进行候选整定：内环1、2、4 kHz，外环100、250、500、800 Hz且不超过内环四分之一；在两种负载模型均稳定的候选中，按模型变载误差选择。五种模式本轮均选择4 kHz内环、800 Hz外环。完整候选记录见tuning_*.json；这不是对全部PI参数的全局最优搜索。')

for start,title in [(0,'单模式变载比较一'),(2,'单模式变载比较二'),(4,'DISO变载与输入信息说明')]:
 page(title)
 stop=min(start+2,5)
 for k in range(start,stop):figure(S[k],k+1)
 if start==4:
  para('NN输入为电感电流、受控电压、实际负载电流及参考值；本轮常规双环PI使用电压和电感电流反馈，不使用负载电流前馈。因而，电路和时序一致不等于控制器信息结构完全一致，动态差异不能全部归因于预测机制。')
  para('若论文需要进一步区分网络控制律与负载信息的贡献，应增加相同输入信息的PI加负载前馈对照。DISO还应另做端口功率分配策略一致的比较。本轮没有将这些尚未运行的对照计入结果。')
  table(['模式','反馈段电感峰值 A\nNN / PI'],[[short[i],fmt(S[i]['NN']['feedbackPeakCurrentA'])+' / '+fmt(S[i]['PI']['feedbackPeakCurrentA'])] for i in range(9)],[3.4,3.65])
  para('上表为声明初始化结束后的原始电流绝对峰值，仍包含接管及变载瞬态，不是纯稳态纹波峰值；不用于代替器件应力或实物采样量程验收。')

for start,title in [(5,'模式切换比较一'),(7,'模式切换比较二')]:
 page(title)
 for k in range(start,start+2):figure(S[k],k+1)
 para('本组沿用原模型的辅助开关和模式调度。切换前有0.25 s相同的声明初始化，图中时刻均从初始化结束起算。仿真中的辅助功率路径不能直接视为三MOS实物的热切换方案。')

page('如何复查和使用结果')
para('所有对比电路和结果在pi_comparison目录内生成。正式48_72_120_C220_16_8中的参数、网络、控制律和模板未被本次试验覆盖。公平性检查逐对比较电气连接、功率块参数、仿真时序、占空比限幅和周期均值时间网格；检查结果见fairness_verification.json。')
table(['文件或目录','用途'],[
 ['run_comparison.m','设计、单模式、切换、绘图的统一入口'],
 ['pi_design.json 与 tuning_*.json','冻结的PI参数及全部候选整定记录'],
 ['results/工况/PI.mat 与 NN.mat','全程周期均值、事件局部原始波形、配置与指标'],
 ['results/工况/CMP_*.slx','同一功率电路上的PI和NN独立副本'],
 ['comparison_metrics.csv','36行事件指标，供重新制表'],
 ['figures','九组必要的事件对比图及可编辑FIG'],
 ['build_report.py','由结果生成本Word及Markdown说明']],[2.7,4.35])
para('MATLAB当前目录切到仓库根目录后，执行以下命令即可查看已保存图。它不会重新训练网络。')
for line in ["cd('pi_comparison');","run_comparison('plots');"]:
 p=para(line);p.paragraph_format.space_after=Pt(2)
para('需要重新仿真时运行run_comparison(\'single\')或run_comparison(\'switch\')；已有本次结果会复用。修改PI参数或控制代码后，应先把本目录旧results移到本地归档，再重跑；不要将新设计参数与旧结果混合解释。')
para('本轮只比较已列出的两负载工况及四组模式切换，不包含输入电压扰动、参数失配、多种子统计、有限精度和目标板执行时延。MATLAB仿真耗时只记录运行过程，不作为控制器硬件实时性结论。')
para('设计方法参考MathWorks官方说明：Designing Cascade Control System with PI Controllers；Discrete PID Controller的抗饱和与跟踪说明。原始实验条件和NN权重来源为本项目正式16–8工程。')
para('https://www.mathworks.com/help/control/ug/designing-cascade-control-system-with-pi-controllers.html')
para('https://www.mathworks.com/help/simulink/slref/discretepidcontroller.html')

# Black text throughout, including inherited runs in tables and headers.
for p in doc.paragraphs:
 for r in p.runs:r.font.color.rgb=RGBColor(0,0,0)
for xml in [doc.element,doc.styles.element]:
 for border in xml.xpath('.//w:pBdr'):border.getparent().remove(border)
path=out/'48_72_120_PI与NN_EMPC仿真对比.docx';doc.save(path)
md=['# 48 72 120 V PI与NN EMPC仿真对比','',doc.paragraphs[2].text,'','| 工况 | 最大平台误差 NN/PI % | 最大事件偏差 NN/PI V | 最长恢复 NN/PI μs |','|---|---|---|---|']
for i,s in enumerate(S):md.append('| '+ ' | '.join([short[i],fmt(s['NN']['maximumPlateauErrorPct'],4)+' / '+fmt(s['PI']['maximumPlateauErrorPct'],4),fmt(maxr(s,'NN','peakDepartureV'))+' / '+fmt(maxr(s,'PI','peakDepartureV')),fmt(maxr(s,'NN','recoveryUs'),0)+' / '+fmt(maxr(s,'PI','recoveryUs'),0)])+' |')
md+=['','电气参数、时序、限幅与周期均值时间网格核对通过。指标排除初始化，恢复带为后平台均值±0.1 V，窗口最多3 ms。PI不用负载电流前馈，NN使用负载电流输入，比较不能单独证明预测机制的贡献。','']
for i,s in enumerate(S):md.extend([f'## {s["title"]}',f'![事件比较](../{s["figure"]})',''])
(out/'48_72_120_PI与NN_EMPC仿真对比.md').write_text('\n'.join(md),encoding='utf-8')
print(path)
