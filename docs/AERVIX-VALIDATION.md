# AERVIX TV visual release

The Jeddah image from the supplied assets is used as a static, aspect-preserving background. Its source is 1672×941, not native 4K. The 1600×900 design canvas scales uniformly with letterboxing for other aspect ratios; wallpaper uses aspect-preserving cover (minimal crop, no stretch). The blank gold tile is a decorative texture only. Text, icons, weather, clock and prayers are widgets.

- Arabic RTL home, six category buttons and real installed application icons.
- Directional focus, Enter, numpad Enter, D-pad Select and gamepad A; 180ms gold focus transitions and automatic scroll into view.
- Application inventory, icon cache and launch behavior use the existing AppsService and Android channels. Categories suggest installed media apps by name/package; all visible applications remain accessible through All Apps. Favorites use the existing Favorites category and existing launcher settings.
- Device clock; Jeddah weather from Open-Meteo (30-minute refresh); Jeddah daily prayer timings from Aladhan, Umm al-Qura method, Asia/Riyadh. Next prayer is highlighted. Network requests have 12-second limits, retry on refresh/resume, and explicit unavailable/stale status. Previous-day prayer times are never presented as today's.
- Android package remains `com.omeda.arc`. Version changed to 1.2.3+4130 (ARMv7 split code 5130, previous 5128).
- Release build exclusively uses the four existing AERVIX_RELEASE_* GitHub Secrets. CI verifies APK signing with apksigner against the previous release certificate SHA-256 `3e01112a28d8c117d9042d7e9e17552ef7663eddf0d3cb0fd548221d03e0058e`, package name, increasing version code and ARMv7 native libraries before uploading.

Automated tests cover RTL arrows, repeated key presses, OK, moving between rows, Android Back from the app picker, installed-app launch calls, weather/prayer responses, and offline states. Platform channel and app service tests cover existing native integration contracts. Physical MECOOL hardware is not attached to this environment; device performance, vendor-specific remote keys and an actual in-place installation must be confirmed on that hardware. Signing/package/version verification establishes update identity relative to the prior repository release, not an unknown APK installed from another source.

The subsequently supplied AERVIX logo is the source for the launcher and adaptive Android icons, TV banner and home brand mark. Icon sizes were generated with the existing flutter_launcher_icons dependency; no signing configuration was changed. Local full suite: 184 passed, 4 existing skips. After the icon/header update, all 35 focused remote, data and app integration tests passed again.


## Direct releases and in-app updates

The release workflow now publishes a versioned APK directly in GitHub Releases, alongside release-manifest.json and SHA256SUMS.txt. It rejects reused versions and compares both versionName and versionCode against the preceding release manifest. GitHub release builds explicitly enable ENABLE_SELF_UPDATER.

The updater automatically checks only vipkash13-prog/AERVIX-TV at launch and every six hours. A gold indicator marks available updates. Download and installation each require user consent; Android additionally presents its installer confirmation. If unknown-source permission is needed, the downloaded file is retained for a subsequent installation attempt. Downloads are staged as .part files and renamed only when complete.

The active Android activity checks the APK's package, versionCode and signing certificates against the installed application before invoking the installer. It never uninstalls or clears application data. Native installation and MECOOL performance still require hardware validation.

Final local validation after adding the updater: 192 tests passed, 4 existing skips; scoped Flutter analysis reported no issues. Update tests verify background checks never download/install without consent, explicit download/install approval, permission retry without re-downloading, exact repository selection, ignoring prerelease/ZIP assets, staged downloads and rejection of unsafe asset paths.

An additional RTL stress test traversed 18 installed-app fixtures left to the final offscreen app and right back to the first, then activated both via Enter/Select; it passed without exceptions. This covers automatic scrolling across a long row on a 1280×720 viewport.
