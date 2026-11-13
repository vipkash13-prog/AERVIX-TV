# AERVIX TV — supplied right-menu reference, November 13

The user explicitly requested implementation of the FIRST attached reference, superseding the previous PDF arrangement. The app retains its own AERVIX TV brand, `com.omeda.arc`, old signing certificate, encrypted subscription, preferences, internal player and update consent flow.

## Layout and real actions

- Clean reconstructed Makkah/Jeddah night background, gold arcs, AERVIX brand at top left, upper search/settings/updates/Bluetooth/network controls, real clock/date at top right.
- Five working right-hand menu rows: Movies, Series, Live TV, Today Matches, Apps. No flattened menu or baked-in labels are used.
- Prayer and weather panels below the scene retain actual city data. Gregorian/Hijri dates remain accessible through the clock details. City and language settings are preserved.
- Seven existing favourite apps with original native icons and names inside the large glass dock. Grid at the left opens actual installed apps. Short OK launches; held OK/Menu opens existing app actions; no footer edit button.
- Search chooses a media section and opens its real catalogue with search focused. Sports opens a filtered live-channel list and uses the same internal player and D-pad channel switching.

## Sports data and honest empty states

The sports card reads `get_short_epg` from up to four allowed subscription sports channels. It decodes titles and requires usable Unix timestamps, current Riyadh-day relevance and match-related metadata. Adult titles/flags, forbidden channels, expired programmes and malformed listings are excluded. The card can cycle actual listings with Left/Right; OK plays the corresponding real channel, held OK refreshes. If no guide is supplied, it displays an explicit empty/unavailable state and OK opens sports channels. There are no hardcoded teams, scores, streams or invented official team logos. This is the host's EPG, not an independent guaranteed fixture/score provider.

## Assets and provenance

- `design_sources/tv_wallpapers_2026_11_13/layout_reference_only.jpg`: supplied first reference, never rendered as the interface.
- `makkah_jeddah_clean_generated.png`: AI-assisted background reconstruction without embedded UI.
- `assets/premium_home/makkah_jeddah_fhd.png` and `makkah_jeddah_uhd.png`: proportional 16:9 exports at 1920×1080 and 3840×2160. Generated source is 1672×941; UHD export is not native photographic 4K.
- The green/gold, blue/silver, purple and original Makkah deliverables remain in `assets/tv_wallpapers_4k/` with their own provenance manifest. These prepared alternatives are not automatically bundled/selected in the launcher.

## Remote and validation

Up/Down follows the right menu. Down after Apps enters the last dock slot, Left crosses favourites to the grid. Up from favourites reaches the sports card; Up from information reaches the header. Header controls can be crossed in both directions. Back restores Movies focus on the root, and closes catalogues/player/dialogs at their own levels.

`design_preview/reference_2026_11_13/interface_*.png` are screenshots from the running Flutter widget tree at 1280×720, 1920×1080 and 3840×2160. They use clearly synthetic test programme/account/package data, not a connected MECOOL or real subscriber account. A physical MECOOL and a live subscription were not available in this session. Automated checks cover layout, 200% device text scale, D-pad traversal, app actions, city/language persistence, sports filtering/EPG bounds, source-channel playback and top search routing. Existing playback-resume and Back tests remain required.

Validation record: 253 full-suite tests passed with four pre-existing migration skips. After the final sports-category cache improvement, 39 targeted integration/playback/guide/layout tests passed; scoped analysis and source/asset validation passed. The signed release workflow verifies package, old certificate and increasing ARMv7 version before publication.
