# AERVIX-TV constraints

- Modify only this repository for AERVIX-TV tasks.
- Preserve applicationId and namespace `com.omeda.arc`. Never change the package ID without the user's explicit permission.
- All release APKs and future updates must use the existing GitHub Secrets: AERVIX_RELEASE_KEYSTORE_B64, AERVIX_RELEASE_KEY_ALIAS, AERVIX_RELEASE_KEY_PASSWORD, AERVIX_RELEASE_STORE_PASSWORD.
- Never generate, replace, rotate, print, or commit signing keys or passwords. Never fall back to debug signing for a release.
- Verify the release certificate against the previous signed release, check package identity, and increment versionCode for updates.
- Run relevant tests before release builds. Keep Arabic RTL and remote D-pad, OK, and Back navigation working.
- Use installed application icons and real launch intents, not mockup app images.
- Keep wallpaper aspect ratio; the current supplied background is 1672x941, not native 4K. Do not describe an upscale as original 4K.
- Known previous ARMv7 release: versionCode 5128, certificate SHA-256 `3e01112a28d8c117d9042d7e9e17552ef7663eddf0d3cb0fd548221d03e0058e` (verified from Actions run 42945349016). Validate with apksigner, which supports APK v2/v3 signing; keytool -jarfile alone is insufficient.
- Publish each new version as a stable GitHub Release with a direct APK asset, release-manifest.json and SHA256SUMS.txt, using the signed release workflow. Never overwrite an existing published version; increase both versionName and versionCode.
- Enable the in-app updater for GitHub APKs. It must check only vipkash13-prog/AERVIX-TV releases, preserve application data, require user consent, and verify package/certificate/increasing version before invoking Android's installer. Never uninstall the app for an update.
