# Focus Timer

A Pomodoro-style focus timer for Android, built with Flutter. It has focus, short-break and long-break phases, adjustable durations, auto-start, session dots and a count of today's sessions. Everything is stored on the device, and the app needs no permissions and collects no data.

- Package id: `io.github.shiv8080.focus_timer` (permanent)
- Signed release builds are made by GitHub Actions, so no Android Studio or Android SDK is needed locally.

```
lib/                          app code (timer logic in timer_controller.dart)
test/                         unit + widget tests
android/                      Android project (release signing in app/build.gradle.kts)
assets/icon/                  launcher icon sources
store/                        512×512 store icon + 1024×500 feature graphic
docs/privacy-policy.html      privacy policy, served by GitHub Pages
.github/workflows/release.yml CI: test → build signed arm64 APK
make_upload_key.sh            creates your signing key (run once)
STORE_LISTING.md              store text
```

## Try it locally (web)

```bash
flutter run -d chrome
flutter test
```

## Release, step by step

### 1. Create the GitHub repo and push

1. On GitHub (account **shiv8080**), create a **public** repository named **`focus-timer`**, with no README, licence or `.gitignore`. It needs to be public for free GitHub Pages.
2. Push the code:
   ```bash
   git remote add origin https://github.com/shiv8080/focus-timer.git
   git push -u origin main
   ```

### 2. Create the signing key (once, and keep it forever)

```bash
./make_upload_key.sh
```

The script asks you for a password. It saves the key to `keys/focus-timer-upload.p12` in this project (git-ignored) and copies its base64 to your clipboard.

In the repo, go to **Settings → Secrets and variables → Actions → New repository secret** and add:

| Name | Value |
|---|---|
| `KEYSTORE_BASE64` | paste from clipboard |
| `KEYSTORE_PASSWORD` | the password you chose |

> **Back up `keys/focus-timer-upload.p12` and the password** (in a password manager or other safe storage). Every future update has to be signed with this key. If you lose it, users can't update the app. Never commit the key.

### 3. Build

Go to **Actions → Build signed release → Run workflow**, or push a tag:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

When the run finishes (about 5–8 minutes), download the **focus-timer-apk** artifact. It contains `focus-timer-<version>-arm64.apk`, a small signed APK for 64-bit phones. Install it on your phone to test, and upload the same file to the store. The **debug-symbols** artifact is only needed for decoding crash reports.

### 4. Publish the privacy policy

In the repo, go to **Settings → Pages**. Set Source to *Deploy from a branch*, Branch to `main`, and folder to `/docs`. After a minute the policy is live at:

**https://shiv8080.github.io/focus-timer/privacy-policy.html**

### 5. Publish on PhonePe Appstore (formerly Indus Appstore)

Publishing is free (no registration or listing fee at the time of writing).

1. Sign up at **https://developer.phonepeappstore.com**, verify your email and complete the one-time verification.
2. Create a new app and upload the APK. Choose the **APK** option, not AAB, so your signing key stays with you.
3. Fill in the listing:
   - Text: from `STORE_LISTING.md`
   - Icon: `store/icon-512.png`
   - Feature graphic: `store/feature-graphic.png`
   - Category: Productivity
   - Screenshots: install the APK on a phone and take 2–4 screenshots
4. Privacy policy URL: the GitHub Pages link from step 4.
5. Submit for review. After approval, publish.

### Updating the app later

1. Bump `version:` in `pubspec.yaml`, for example `1.0.1+2`. The number after `+` must go up every time.
2. Commit, then push a new tag (`v1.0.1`).
3. Upload the new APK as a new release in the console.

## Ideas for later

- [ ] Notification when a phase ends while the app is in the background
- [ ] Turn on Do Not Disturb during focus sessions (needs the notification-policy permission; update the privacy policy too)
- [ ] Keep the screen on while running
