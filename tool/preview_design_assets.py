"""Render the exported files on checkerboards; do not alter the assets."""
import json,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'assets/assets_manifest.json').read_text())
tmp=Path('/tmp/aervix-preview-tiles');tmp.mkdir(exist_ok=True)
files=[]
for index,item in enumerate(manifest['files']):
    target=tmp/f'{index:03}.png'
    source=root/item['file']
    name=source.stem
    caption=f'{name}\n{item["width"]}x{item["height"]} | {item["provenance"].split("_")[0]}'
    cmd=['magick','(','-size','224x158','pattern:checkerboard','-evaluate','Multiply','.28',')',
         '(',str(source),'-thumbnail','204x138',')','-gravity','center','-compose','over','-composite',
         '(','-background','#101721','-fill','#efdbad','-font','/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf','-pointsize','11','-size','224x44','-gravity','center','caption:'+caption,')','-append',str(target)]
    subprocess.run(cmd,check=True)
    files.append(str(target))
preview=root/'design_preview';preview.mkdir(exist_ok=True)
subprocess.run(['magick','montage',*files,'-tile','8x','-geometry','224x202+4+4','-background','#080d16',str(preview/'assets_contact_sheet.png')],check=True)
print(preview/'assets_contact_sheet.png')
