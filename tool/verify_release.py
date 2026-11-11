"""Verify published-update identity and monotonically increasing versions."""
import hashlib
import json
import pathlib
import re
import shutil

root = pathlib.Path(__file__).resolve().parents[1]
package = (root / 'package.txt').read_text()
certificate = (root / 'certificate.txt').read_text()
expected = '3e01112a28d8c117d9042d7e9e17552ef7663eddf0d3cb0fd548221d03e0058e'
assert f'certificate SHA-256 digest: {expected}' in certificate, 'Unexpected signing certificate'
match = re.search(r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", package)
assert match, 'Missing APK package metadata'
package_name, code, version = match.groups()
assert package_name == 'com.omeda.arc', 'Package identity changed'
assert "native-code: 'armeabi-v7a'" in package, 'Missing ARMv7 libraries'
assert "application-label:'AERVIX TV'" in package, 'Incorrect app label'
assert re.fullmatch(r'\d+\.\d+\.\d+', version), 'Use a stable major.minor.patch version'
previous_file = root / 'previous-release/release-manifest.json'
previous = json.loads(previous_file.read_text()) if previous_file.exists() else {
    'versionCode': 5128, 'versionName': '1.2.1', 'packageName': package_name,
    'certificateSha256': expected,
}
assert previous['packageName'] == package_name and previous['certificateSha256'] == expected
assert int(code) > int(previous['versionCode']), 'Increase versionCode before publishing an update'
assert tuple(map(int, version.split('.'))) > tuple(map(int, previous['versionName'].split('.'))), 'Increase versionName before publishing'
apk = root / 'build/app/outputs/flutter-apk/app-armeabi-v7a-github-release.apk'
output = root / 'dist'
output.mkdir(exist_ok=True)
name = f'AERVIX-TV-{version}-armeabi-v7a.apk'
shutil.copyfile(apk, output / name)
digest = hashlib.sha256(apk.read_bytes()).hexdigest()
manifest = dict(packageName=package_name, versionName=version, versionCode=int(code),
                certificateSha256=expected, abi='armeabi-v7a', apk=name, sha256=digest)
(output / 'release-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
(output / 'SHA256SUMS.txt').write_text(f'{digest}  {name}\n')
print(json.dumps(manifest, indent=2))
