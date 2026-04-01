# Splash Screen Hang - Fixes Attempted

1. Removed `await` from `WifiWatcherService.configure()` in `main()` — was blocking `runApp()`
2. Added 5-second timeout to `Firebase.initializeApp()` in `main()` — was blocking on slow/no network
3. Removed `await` from `DetectionService.instance.start()` in `_checkNotificationLaunch()` — was blocking app load while connecting to camera
4. Added 3-second timeouts to all `FlutterSecureStorage` reads in `_checkNotificationLaunch()` — Android keystore can deadlock and hang indefinitely
5. Added `_ticking` guard to background service `_tick()` — without it, if a tick hangs (e.g. WiFi check stalls when device sleeps), the 30-second timer keeps firing new ticks. After 20 minutes, dozens of concurrent ticks pile up all reading from storage simultaneously, blocking the main app from accessing storage on next open
