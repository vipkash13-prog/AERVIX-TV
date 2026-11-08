# AERVIX TV

AERVIX TV is a planned lightweight Android TV adaptation of [NuvioTV](https://github.com/NuvioMedia/NuvioTV).

## Project status
Initial setup and upstream source review. **No APK has been built yet.**

## Goals
- Android TV remote-first experience, including Arabic RTL and English.
- Smooth performance on 32-bit ARM Android TV devices (armeabi-v7a).
- Distinct app name, icon and package identity.
- Preserve compatible upstream playback, catalog, subtitles and settings features.
- Produce a directly installable APK using GitHub Actions.

## Upstream and license
Upstream: https://github.com/NuvioMedia/NuvioTV

Upstream is licensed under GNU GPL v3.0. Any distribution of this derivative must comply with GPLv3, preserve appropriate copyright/license notices, and provide corresponding source code. Review third-party assets and dependencies separately.

## Release signing policy
- Generate **one permanent release keystore** before the first release build.
- Store keystore (base64), alias and passwords as GitHub Actions secrets; never commit them.
- Maintain a secure offline backup of the keystore and credentials.
- Never rotate the release key without explicit owner approval.
- Debug APKs are not interchangeable with release-signed update APKs.
- Do not claim update compatibility until package ID and certificate are verified.

## Next steps
1. Import and inspect upstream source and build configuration.
2. Audit app identity, 32-bit ABI compatibility and Android TV support.
3. Add branding/localization and performance improvements.
4. Configure reproducible CI builds and secure release signing.
5. Verify an APK on the target Android TV device.

This repository is independent of Ouswis and Quswis-tvos-launcher.
