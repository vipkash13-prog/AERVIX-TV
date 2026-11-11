"""Package the verified asset library and its sources without packaging an APK."""
import json
import re
import zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
m=json.loads((root/'assets/assets_manifest.json').read_text())
paths={root/x['file'] for x in m['files']}
paths.update(root/x for x in ['assets/assets_manifest.json','assets/README_AR.md','docs/CODEX-ASSET-INTEGRATION.md','design_preview/assets_contact_sheet.png','design_preview/validation_report.json','tool/export_design_assets.py','tool/validate_design_assets.py','tool/preview_design_assets.py'])
for path in (root/'design_sources').rglob('*'):
    if path.is_file():paths.add(path)
for name in ['interface_preview_fhd.png','README_AR.md']:
    path=root/'design_preview'/name
    if path.exists():paths.add(path)
version=re.search(r'^version:\s*(\d+\.\d+\.\d+)',(root/'pubspec.yaml').read_text(),re.M)[1]
output=root/f'build/design/AERVIX-TV-DESIGN-ASSETS-v{version}.zip'
output.parent.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for path in sorted(paths):archive.write(path,path.relative_to(root))
with zipfile.ZipFile(output) as archive:assert archive.testzip() is None
print(output)
print(f'{len(paths)} files, {output.stat().st_size:,} bytes')
