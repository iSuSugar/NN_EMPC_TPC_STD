"""Read-only source inventory; write audit metadata in this directory."""
from pathlib import Path
import csv,re
from pypdf import PdfReader

audit=Path(__file__).resolve().parent
project=audit.parent
source=project.parent.parent/'ICPRE会议论文资料+修改版'
paper=next((source/'学习文献').glob('毕设*.pdf'))
reader=PdfReader(paper)
items={}
for i,page in enumerate(reader.pages):
    text=page.extract_text() or ''
    # Numbered formulas; index occurrence only, not a claim of verified derivation.
    for a,b in re.findall(r'[（(]\s*([2-4])\s*[-－–]\s*(\d+)\s*[)）]',text):
        key=('公式',f'{a}-{b}')
        items.setdefault(key,set()).add(i+1)
    for kind,a,b in re.findall(r'(图|表)\s*([1-4])\s*[-－–]\s*(\d+)',text):
        key=(kind,f'{a}-{b}')
        items.setdefault(key,set()).add(i+1)

with (audit/'论文公式图表编号清单.csv').open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.writer(f);w.writerow(['类型','编号','PDF出现页_引用与正文均计入','逐项推导或复现状态','说明'])
    for (kind,number),pages in sorted(items.items(),key=lambda x:(x[0][0],tuple(map(int,x[0][1].split('-'))))):
        w.writerow([kind,number,';'.join(map(str,sorted(pages))),'待逐项核对','文本自动检索；页码非必然为定义页；需视觉复核避免漏号、错号'])
with (audit/'原资料文件总清单.csv').open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.writer(f);w.writerow(['原资料相对路径','绝对路径','扩展名','字节数','状态'])
    for p in sorted(source.rglob('*')):
        if p.is_file():w.writerow([str(p.relative_to(source)),str(p),p.suffix,p.stat().st_size,'已登记；存在不代表已理解或验收'])
print('PDF pages:',len(reader.pages),'numbered entries:',len(items))
print('Formula inventory is provisional; no entry automatically marked complete.')
