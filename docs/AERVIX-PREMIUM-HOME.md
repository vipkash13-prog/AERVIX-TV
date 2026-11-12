# AERVIX TV — November 12 reference implementation

The new supplied PDF replaces the former sidebar layout. The home screen has no fixed brand label or sidebar, three working Xtream entry cards, status controls and clock, weather, five daily prayers, Gregorian/Hijri date, seven persisted app favourites and an installed-apps grid. The background is the unchanged uploaded 1280×720 JPEG; the interface renders at native FHD/UHD output, but the photograph is not native 4K.

## Sources and implementation

- `design_sources/TV_Box_Launcher_Design_Spec.pdf`: supplied three-page specification. Some source text is clipped/missing in the PDF itself; implementation follows its readable requirements and visible reference. Page two's example logo list is illustrative; runtime always uses installed package artwork.
- `assets/premium_home/jeddah_night.jpg` and `assets_manifest.json`: exact original background with hash and native source dimensions. The second supplied illustration is kept as `design_sources/premium_dock_reference.jpg`, outside the APK.
- `lib/widgets/aervix_home.dart`: real interactive layout and bounded network data refresh. Existing internal playback, filtering, account storage and update consent remain in their original modules. The resume-on-reconnect fix remains enabled.
- `lib/widgets/premium_glass.dart`: static gradients and 180ms focus transitions, without backdrop blur, shaders or continuous animation.
- `lib/widgets/reference_dock.dart`: seven favourites using original installed icons; short OK launches, held OK/Menu opens app actions. The eighth grid control opens all installed visible applications. No footer edit button.
- `lib/providers/home_preferences.dart`: persisted Arabic/English and city selection. Locale changes keep positions fixed. City changes invalidate stale responses and fetch real coordinates; no mock readings are used at runtime.
- Hijri dates come from Aladhan response metadata. Unavailable or stale date/weather/prayer data displays an unavailable state rather than fabricated values.

## Remote map

Left/right follow the visible card positions. Up moves from content to information/status controls. Down moves from content to favourites. Right past the seventh favourite reaches All Apps. Back closes a dialog/catalogue first; on the home screen it restores Movies focus. Header status controls open native Wi-Fi/Bluetooth/date settings. The settings gear exposes city/language, account editing, advanced settings and the original in-app update flow.

## Validation and limitations

The automated suite covers layout at 1280×720, 1920×1080 and 3840×2160, 200% device text scale, focus traversal, real app launch calls, app actions, internal Xtream routing, city-response races, preference persistence and fixed English geometry. Existing player tests cover retry cancellation, VOD resume and movie/episode Back restoration.

`design_preview/premium_home/interface_*.png` are screenshots from the running Flutter widget tree using test data and fixture package artwork. They are not photographs or screenshots from a connected MECOOL. No physical TV device or live subscription was available in this session. The release workflow must pass tests, sign using existing Secrets and verify package/certificate/increasing ARMv7 version before publishing a direct APK.

Final local verification: 250 tests passed with four existing migration skips; scoped analysis passed and asset provenance validation checked the supplied unchanged background. Signed publication additionally checks `com.omeda.arc`, the original certificate and ARMv7 versionCode 5140 against the previous release. Package and signing changes are prohibited.
