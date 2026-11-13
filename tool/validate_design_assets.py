"""Validate exported PNG dimensions, genuine alpha, provenance and file hashes."""
import hashlib
import json
from pathlib import Path
from PIL import Image

root=Path(__file__).resolve().parents[1]
m=json.loads((root/'assets/assets_manifest.json').read_text())
errors=[]
for item in m['files']:
    path=root/item['file']
    try:
        with Image.open(path) as im:
            im.load()
            assert im.format=='PNG','not PNG'
            assert im.size==(item['width'],item['height']),'dimension mismatch'
            if path.name not in ['jeddah_background_4k.png','jeddah_background_fhd.png']:
                assert im.mode=='RGBA','missing alpha channel'
                lo,hi=im.getchannel('A').getextrema()
                assert hi>0,'fully empty image'
                if path.name!='background_overlay.png':
                    assert lo==0,'no fully transparent pixels'
                    for point in [(0,0),(im.width-1,0),(0,im.height-1),(im.width-1,im.height-1)]:
                        assert im.getpixel(point)[3]==0,'opaque export corner'
            if path.parent.name in ['topbar','weather','prayer','categories','entertainment','app_logos'] and (path.name.startswith('icon_') or path.parent.name=='app_logos' or path.name.startswith('weather_')):
                assert im.size==(256,256),'icon must be 256x256'
            if path.name in ['card_app_normal.png','card_app_focused.png']:assert im.size==(320,320)
            if path.name in ['card_category_normal.png','card_category_focused.png']:assert im.size==(480,300)
            if path.name=='jeddah_background_4k.png':assert im.size==(3840,2160) and item['native_4k'] is False
            if path.name=='jeddah_background_fhd.png':assert im.size==(1920,1080)
        assert hashlib.sha256(path.read_bytes()).hexdigest()==item['sha256'],'checksum mismatch'
        assert item['provenance'],'missing provenance'
        if item['source']:assert (root/item['source']).exists(),'missing source'
    except Exception as e:errors.append({'file':item['file'],'error':str(e)})
reference_file = root/'assets/reference_ui/assets_manifest.json'
reference_count = 0
if reference_file.exists():
    reference = json.loads(reference_file.read_text())
    for item in reference['files']:
        reference_count += 1
        path = root/item['file']
        try:
            with Image.open(path) as im:
                im.load()
                assert list(im.size) == item['size'], 'reference export dimension mismatch'
                assert im.format == 'PNG'
            assert hashlib.sha256(path.read_bytes()).hexdigest() == item['sha256'], 'reference checksum mismatch'
            if 'background' in path.name or 'jeddah' in path.name:
                assert item['native_4k'] is False, 'resampled wallpaper must be disclosed'
        except Exception as error:
            errors.append({'file': item['file'], 'error': str(error)})
premium_file=root/'assets/premium_home/assets_manifest.json'
premium_count=0
if premium_file.exists():
    premium=json.loads(premium_file.read_text())
    for item in premium['files']:
        premium_count+=1
        path=root/item['file']
        try:
            with Image.open(path) as im:
                assert list(im.size)==item['size'],'premium background dimensions changed'
            assert hashlib.sha256(path.read_bytes()).hexdigest()==item['sha256'],'premium source checksum mismatch'
            assert item['native_4k'] is False,'native resolution provenance missing'
        except Exception as error: errors.append({'file':item['file'],'error':str(error)})
wallpapers_file=root/'assets/tv_wallpapers_4k/assets_manifest.json'
wallpapers_count=0
if wallpapers_file.exists():
    for item in json.loads(wallpapers_file.read_text())['files']:
        wallpapers_count+=1
        path=root/item['file']
        try:
            with Image.open(path) as im:
                im.verify()
                assert im.size==(3840,2160),'wallpaper must be 16:9 UHD'
                assert im.format=='PNG'
            assert hashlib.sha256(path.read_bytes()).hexdigest()==item['sha256'],'wallpaper checksum mismatch'
            assert item['native_4k'] is False,'source resolution disclosure missing'
            assert (root/item['source']).exists(),'missing wallpaper source'
        except Exception as error: errors.append({'file':item['file'],'error':str(error)})
report={'checked_files':len(m['files']), 'reference_exports_checked':reference_count,'premium_exports_checked':premium_count,'wallpaper_exports_checked':wallpapers_count,'errors':errors,'unavailable_logos':m['unavailable_official_logos'],'native_4k':False,'technical_validation_passed':not errors,'complete_static_logo_set':not m['unavailable_official_logos']}
(root/'design_preview').mkdir(exist_ok=True)
(root/'design_preview/validation_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
if errors:raise SystemExit(1)
