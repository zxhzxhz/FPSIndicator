# FPSIndicator

real-time fps indicator for ios games

> Fork of [brendonjkding/FPSIndicator](https://github.com/brendonjkding/FPSIndicator) with fixes
> that make it usable as an **injected tweak** (LiveContainer / sideload dylib injection /
> any tweak-injection tool), built by GitHub Actions.

## Fork changes

1. **Metal games are actually counted now.**
   Upstream hooked `CAMetalDrawable` — but that is an ObjC *protocol*, not a class, so
   `objc_getClass()` never found it and the Metal hooks silently never ran. This fork hooks
   the real `CAMetalLayer -nextDrawable` (called once per rendered frame, the same mechanism
   used by working FPS counters).
2. **Enabled by default when injected.**
   Upstream returned early unless the app was whitelisted in the jailbroken Settings app
   (preference file under `/var/mobile/...`). When no preference file exists, the tweak now
   stays enabled, so a freshly injected dylib "just works".
3. **Optional per-app config** — drop `FPSIndicator.plist` into the target app's `Documents`
   folder:
   ```xml
   <plist version="1.0"><dict>
     <key>enabled</key><true/>
     <key>fpsMode</key><integer>1</integer> <!-- 1 = rolling average, 2 = per second -->
     <key>color</key><string>#ffff00</string>
     <key>apps</key><array>                <!-- optional whitelist (bundle ids) -->
       <string>com.example.game</string>
     </array>
   </dict></plist>
   ```
4. **Build fixes**: added the missing `control` file, added the `libcolorpicker` include
   path, `ARCHS = arm64 arm64e` targeting iOS 14+, preference bundle is opt-in
   (`make FPS_WITH_PREFS=1`, requires AltList).

## Usage — injection (e.g. LiveContainer)

1. Get `FPSIndicator.dylib` from an Actions artifact / release.
2. LiveContainer: put it into `Documents/Tweaks/FPSIndicator/FPSIndicator.dylib`.
3. Assign that tweak folder to the target app (app menu → Tweak Folder), then launch the app.
4. The FPS label appears at the top-right after the first touch of the screen
   (the label is created lazily on the first `UIWindow -hitTest:` call, same as upstream).

## Building

```sh
# plain dylib (injection builds come from CI too)
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless

# including the jailbreak preference bundle (needs AltList in $THEOS)
make package FPS_WITH_PREFS=1
```

## Special thanks
- [masagrator/NX-FPS](https://github.com/masagrator/NX-FPS)
- [JoeyDeVries/LearnOpenGL](https://github.com/JoeyDeVries/LearnOpenGL)
- [loyinglin/LearnMetal](https://github.com/loyinglin/LearnMetal)
