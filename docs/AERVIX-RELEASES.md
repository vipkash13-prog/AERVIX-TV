# Publishing an AERVIX TV update

1. Increase both the semantic version and build number in pubspec.yaml. The current release is 1.2.5+4132 (ARMv7 versionCode 5132).
2. Commit the tested changes to AERVIX-TV. Run the signed APK workflow on that commit/branch, or push its matching version tag (for example v1.2.4 for version 1.2.4+4131).
3. The workflow analyzes and tests the interface/updater, builds ARMv7 using the four existing AERVIX_RELEASE_* secrets, verifies signing/package/version, and publishes a direct APK asset in a stable GitHub Release. It refuses to overwrite an existing release version or downgrade a previous release identity.
4. Subsequent installed versions check Releases automatically at launch and every six hours. Users select the update button, approve downloading, then approve installation in the application and Android installer. If Android asks for unknown-app installation permission, grant it and return to the update button. No uninstall is needed.

The applicationId remains com.omeda.arc. Do not replace signing keys. Public certificate SHA-256: 3e01112a28d8c117d9042d7e9e17552ef7663eddf0d3cb0fd548221d03e0058e.

A device currently running an earlier build without the AERVIX updater must receive this APK once as an in-place update. From this version onward the in-app updater uses this repository. The Android installer and the pre-install validation reject different packages/certificates or non-increasing version codes.
