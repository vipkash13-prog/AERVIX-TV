"""Export source artwork/generated reconstructions into named PNG assets.

ImageMagick handles lossless pixel extraction, alpha matting and export sizing.
No official third-party logo is drawn or inferred. The manifest records provenance.
"""
import hashlib
import json
import subprocess
from pathlib import Path
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets'
SOURCES = ROOT / 'design_sources'
TEMP = Path('/tmp/aervix-export')
TEMP.mkdir(exist_ok=True)
records = []
for name in ['branding','backgrounds','topbar','weather','prayer','categories','cards','entertainment','app_logos','effects']:
    (ASSETS / name).mkdir(exist_ok=True)


def magick(*args):
    subprocess.run(['magick', *map(str,args)], check=True, stdout=subprocess.DEVNULL)


def record(path, source, kind, box=None, notes='', **extra):
    with Image.open(path) as im:
        width,height=im.size
        alpha=im.getchannel('A') if im.mode=='RGBA' else None
        alpha_range=list(alpha.getextrema()) if alpha else None
        native=Image.open(source).size if source and Path(source).exists() else None
    records[:] = [x for x in records if x['file'] != str(path.relative_to(ROOT))]
    records.append(dict(file=str(path.relative_to(ROOT)),width=width,height=height,
        format='PNG',alpha_range=alpha_range,source=str(Path(source).relative_to(ROOT)) if source else None,
        source_native_size=native,source_bounds=box,provenance=kind,notes=notes,
        sha256=hashlib.sha256(path.read_bytes()).hexdigest(),**extra))


def export(group, name, source, size=(256,256), box=None, kind='extracted', black_matte=False, notes=''):
    path=ASSETS/group/(name+'.png')
    args=[source]
    if box:
        x0,y0,x1,y1=box
        args += ['-crop',f'{x1-x0}x{y1-y0}+{x0}+{y0}','+repage']
    if black_matte:
        # The opaque source contains no original alpha: estimate a soft matte.
        expr = 'max(0,min(1,(max(r,max(g,b))-0.30)/0.25))' if (group=='topbar' and name.startswith('icon_')) or name in ['icon_play','logo_aervix_full'] else 'max(r,max(g,b))<0.012?0:min(1,max(r,max(g,b))/0.22)'
        args += ['-alpha','on','-channel','A','-fx',expr,'+channel']
        notes += ' Original is RGB on black; alpha is a reconstructed soft black matte, not recovered original alpha.'
    stage=TEMP/(group+'_'+name+'.png')
    magick(*args,f'PNG32:{stage}')
    with Image.open(stage) as im:
        alpha=np.asarray(im)[:,:,3]
        yy,xx=np.where(alpha>6)
        if len(xx)==0:raise ValueError(f'Empty source for {name}')
        left=max(0,int(xx.min())-8);top=max(0,int(yy.min())-8)
        right=min(im.width,int(xx.max())+9);bottom=min(im.height,int(yy.max())+9)
    resize=f'{size[0]-32}x{size[1]-32}'
    if name in ['card_app_normal','card_app_focused']:
        sy,sx=np.where(alpha>230)
        scale=min(224/max(int(sx.max()-sx.min()+1),int(sy.max()-sy.min()+1)),(size[0]-16)/(right-left),(size[1]-16)/(bottom-top))
        resize=f'{round((right-left)*scale)}x{round((bottom-top)*scale)}'
    magick(stage,'-crop',f'{right-left}x{bottom-top}+{left}+{top}','+repage',
           '-filter','Lanczos','-resize',resize,
           '-background','none','-gravity','center','-extent',f'{size[0]}x{size[1]}',f'PNG32:{path}')
    record(path,source,kind,box,notes,aspect_policy='contain_with_transparent_padding',transparency_reconstructed=black_matte)
    return path


def alias(group,name,source,size=(256,256),notes=''):
    return export(group,name,source,size,kind='derived_from_exported_asset',notes=notes)

raw=SOURCES/'raw_assets_sheet.png'
ref=SOURCES/'reference_contact_sheet.jpg'
logo=export('branding','logo_aervix',raw,box=[30,8,231,168],black_matte=True)
alias('branding','logo_aervix_small',logo,(128,128))
export('branding','logo_aervix_full',ref,(1024,256),[16,3,325,91],black_matte=True,notes='Original user-provided complete wordmark, enlarged for consistent export canvas; not vector artwork.')

for name,box in {
 'wifi':[324,54,398,117],'bluetooth':[484,49,542,119],
 'settings_top':[631,52,700,118],'refresh':[783,50,855,121],
 'notifications':[941,51,1004,122],'display':[1085,53,1167,119],
 'power':[1245,48,1317,122],
}.items():export('topbar','icon_'+name,raw,box=box,black_matte=True)

for name,box in {
 'sunny':[227,165,333,265],'partly_cloudy':[385,165,510,260],
 'cloudy':[568,160,696,241],'rain':[742,161,867,266],
 'thunder':[901,156,1027,262],'snow':[1062,158,1188,265],
 'night_cloudy':[1230,156,1370,260],'night':[1401,158,1498,263],
}.items():export('weather','weather_'+name,raw,box=box,black_matte=True)

for name,box in {
 'play':[144,295,205,359],'clapperboard':[341,269,474,391],
 'popcorn':[541,262,656,392],'film_reel':[711,269,866,391],
 'football':[912,269,1042,395],'gamepad':[1095,275,1262,389],
 'star':[1293,269,1416,388],
}.items():export('entertainment','icon_'+name,raw,box=box,black_matte=True)
settings=export('categories','icon_settings',raw,box=[1446,273,1567,390],black_matte=True)
mosque=export('prayer','icon_mosque',raw,box=[1408,5,1665,159],black_matte=True)

# Preserve the additional visible raw cards and button assemblies as separate assets.
for name,box in {
 'source_card_large':[8,397,390,605],'source_card_medium':[393,397,769,604],
 'source_card_glass':[9,612,398,780],'source_card_pill':[401,616,731,690],
 'source_card_small':[404,706,721,776],
}.items():export('cards',name,raw,(800,440),box,black_matte=True,notes='Original empty source card; canvas padded without stretching.')
for index,name in enumerate(['wifi','bluetooth','settings','refresh','notifications','display','power']):
    x0=[293,444,597,748,902,1055,1208][index]
    export('topbar','button_'+name+'_source',raw,box=[x0,23,x0+138,145],black_matte=True,notes='Original complete button including its original glyph.')

supp=SOURCES/'supplementary_icons.png'
supp_map=[
 ('weather','weather_humidity'),('weather','weather_wind'),('weather','weather_temperature'),('prayer','icon_sunrise'),('prayer','icon_prayer'),('prayer','icon_moon'),
 ('categories','icon_live_tv'),('categories','icon_anime'),('categories','icon_apps'),('categories','icon_search'),('entertainment','icon_arrow_left'),('entertainment','icon_arrow_right'),
 ('effects','gold_glow'),('effects','gold_separator'),('prayer','prayer_row_selected'),('effects','focus_glow'),('topbar','top_button_frame'),('cards','button_gold'),
 ('prayer','icon_calendar'),('weather','icon_location'),('prayer','icon_prayer_hands'),('categories','icon_favorites_outline'),('categories','icon_back'),('prayer','icon_sunrise_cloudy'),
]
for idx,(group,name) in enumerate(supp_map):
    col,row=idx%6,idx//6
    # Atlas has true alpha. Export directly, retaining transparent glows.
    size=(640,112) if name=='prayer_row_selected' else (768,160) if name=='gold_separator' else (512,512) if name in ['gold_glow','focus_glow'] else (480,160) if name=='button_gold' else (256,256)
    bounds=[290,620,490,680] if name=='gold_separator' else [col*256,row*256,(col+1)*256,(row+1)*256]
    export(group,name,supp,size,bounds,kind='generated_additional',notes='Supplementary element reconstructed/generated to match the supplied gold identity; not claimed as extracted original.')

cards=SOURCES/'reconstructed_cards.png'
card_specs={
 'card_weather':([34,85,543,355],(800,440)),
 'card_prayer':([625,16,915,407],(400,560)),
 'card_glass_dark':([994,88,1503,359],(800,440)),
 'card_app_normal':([137,431,441,731],(320,320)),
 'card_app_focused':([560,410,979,750],(320,320)),
 'card_category_normal':([1010,442,1491,721],(480,300)),
 'card_category_focused':([45,732,535,1016],(480,300)),
}
for name,(box,size) in card_specs.items():export('cards',name,cards,size,box,kind='reconstructed',notes='Empty card rebuilt from source styling; no embedded text or icons.')
export('prayer','prayer_row_selected',cards,(640,112),[1004,824,1495,927],kind='reconstructed',notes='Long blank selection strip rebuilt from the supplied styling.')
alias('topbar','top_button_frame',ASSETS/'cards/card_app_normal.png')
alias('topbar','top_button_frame_focused',ASSETS/'cards/card_app_focused.png')
alias('prayer','prayer_panel',ASSETS/'cards/card_prayer.png',(400,560))
alias('cards','card_category_selected',ASSETS/'cards/card_category_focused.png',(480,300))

for name,source in {
 'icon_movies':ASSETS/'entertainment/icon_film_reel.png',
 'icon_series':ASSETS/'entertainment/icon_clapperboard.png',
 'icon_sports':ASSETS/'entertainment/icon_football.png',
 'icon_favorites':ASSETS/'entertainment/icon_star.png',
}.items():alias('categories',name,source)

export('backgrounds','gold_waves_bottom',SOURCES/'reconstructed_waves.png',(1920,300),kind='reconstructed',notes='Rebuilt from gold footer motif to remove all water/city contamination.')
for name,size in [('jeddah_background_4k',(3840,2160)),('jeddah_background_fhd',(1920,1080))]:
    path=ASSETS/'backgrounds'/(name+'.png');src=SOURCES/'reconstructed_jeddah.png'
    magick(src,'-resize',f'{size[0]}x{size[1]}^','-gravity','center','-extent',f'{size[0]}x{size[1]}',f'PNG24:{path}')
    record(path,src,'reconstructed_and_resampled',notes='AI-reconstructed clean scene, natively 1672x941, exported by aspect-preserving resampling and minimal crop. NOT native photographic 4K; no UI or typography.',native_4k=False)
path=ASSETS/'backgrounds/background_overlay.png'
magick('-size','1920x1080','gradient:#000000A0-#00000020',f'PNG32:{path}')
record(path,None,'procedural',notes='Lightweight true-alpha dark vertical gradient; UI text stays programmatic.')

# Only documented official logo sources are exported. All others remain explicitly unavailable.
logos=SOURCES/'official_logos'
logo_info=json.loads((logos/'sources.json').read_text()) if (logos/'sources.json').exists() else []
logo_names={'apple_tv':'Apple TV','nuvio_tv':'Nuvio TV','stremio':'Stremio','shahid':'Shahid','aiostreams':'AIOStreams','movieboxpro':'MovieBoxPro','yacine_tv':'Yacine TV','vlc':'VLC','mx_player':'MX Player'}
missing=[]
for name,label in logo_names.items():
    info=next((x for x in logo_info if x['name']==name and x.get('status')=='downloaded_official'),None)
    if info:
        export('app_logos',name,logos/(name+'.source'),kind='official_source',notes='Official published application artwork. Intentional brand tile backgrounds are retained; export canvas is transparent.')
        records[-1]['official_source_url']=info['source_url']; records[-1]['download_url']=info['download_url']
    else:missing.append(dict(name=label,file=None,status='requires_verified_source_or_installed_package',reason='No verified official artwork available. A mock logo is not exported. Runtime must use PackageManager icons.'))
export('app_logos','aervix_tv',raw,box=[30,8,231,168],black_matte=True,kind='user_provided_brand',notes='User-provided new AERVIX brand mark. The installed Android launcher icon is not changed by this library export.')

manifest=dict(schema_version=1,original_source=dict(file='design_sources/raw_assets_sheet.png',width=1672,height=941,mode='RGB',original_alpha=False),
    native_4k=False,files=records,unavailable_official_logos=missing,
    important_notes=['Black matte alpha is reconstructed because source contains no original alpha.','No mockup application logo is accepted as official.','The 3840x2160 file is a reconstructed/resampled export, not a native 4K photograph.','Text, dates, clock, weather values and prayer values must remain runtime widgets.'])
(ASSETS/'assets_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(f'Exported {len(records)} assets; missing verified app logos: '+', '.join(x['name'] for x in missing))
