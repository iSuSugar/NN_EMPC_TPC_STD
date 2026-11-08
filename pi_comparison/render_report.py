"""Windows Word render helper for visual review. Requires pywin32 and pypdfium2.
Uses a separate Word instance and leaves all user Word sessions untouched.
"""
from pathlib import Path
import sys
import win32com.client
import pywintypes
import pypdfium2 as pdfium
from PIL import Image,ImageDraw

root=Path(__file__).resolve().parent
source=root/'report/48_72_120_PI与NN_EMPC仿真对比.docx'
qa=root/'.build/render';qa.mkdir(parents=True,exist_ok=True)
pdf=qa/'word_preview.pdf'
if '--raster-only' not in sys.argv:
 app=win32com.client.DispatchEx('Word.Application');app.Visible=False;app.DisplayAlerts=0;app.AutomationSecurity=3
 try:
  d=app.Documents.Open(str(source),ReadOnly=True,AddToRecentFiles=False)
  d.Fields.Update();d.Repaginate();print('WORD_PAGES',d.ComputeStatistics(2))
  d.ExportAsFixedFormat(str(pdf),17)
  d.Close(False)
 finally:
  try:app.Quit()
  except AttributeError:pass  # Word can release an invisible automation server after its last document closes.
  except pywintypes.com_error as e:
   if e.hresult not in (-2147023170,-2147023174,-2147417848):raise
pages=pdfium.PdfDocument(str(pdf))
for i,p in enumerate(pages):p.render(scale=1.5).to_pil().save(qa/f'page-{i+1}.png')
for k in range(0,len(pages),4):
 sheet=Image.new('RGB',(1100,1500),'#ddd');draw=ImageDraw.Draw(sheet)
 for i in range(k,min(k+4,len(pages))):
  im=Image.open(qa/f'page-{i+1}.png');im.thumbnail((530,710));x=(i-k)%2*550+10;y=(i-k)//2*750+25
  sheet.paste(im,(x,y));draw.text((x,y-20),f'Page {i+1}',fill='black')
 sheet.save(qa/f'sheet-{k//4+1}.png')
print('RENDERED',len(pages))
