# Toastr (100% Serverless On-Device Edition)

A clean-room Flutter implementation of **Toastr (`com.atinnovations.toastr`)** that runs **100% locally on your Android phone and iPhone with $0 hosting costs**.

## How It Works Without Any Backend Server

In the commercial Toastr app, your phone's WebView cookies (`Swiggy`, `Zomato`, `Blinkit`, `Zepto`, `Instamart`, `BigBasket`) were uploaded to `/user/sync-website-data` and AWS S3.

In this **Serverless Local Engine** edition:
1. **100% Private Local Session Vault** ([`webview_session_helper.dart`](lib/services/webview_session_helper.dart)): You can log in to your food & grocery accounts inside the built-in `InAppWebView` ([`platform_login_webview_screen.dart`](lib/screens/platform_login_webview_screen.dart)). Your cookies and `localStorage` tokens stay strictly in your phone's local `SharedPreferences` and are **never sent to any external server**.
2. **Real-Time On-Device Scraping & Headless WebView Fallback** ([`on_device_scraper_service.dart`](lib/services/on_device_scraper_service.dart)):
   - Queries **Swiggy** (`/dapi/restaurants/search/v3`, `/dapi/menu/pl`) and **Zomato** (`/webroutes/search/home`) concurrently from your phone's residential IP.
   - Queries **Blinkit** (`/v1/layout/search`), **Zepto** (`/api/v3/search`), **Swiggy Instamart** (`/api/instamart/search`), and **BigBasket** (`/listing-svc/v2/products`) using your GPS coordinates.
   - If a platform's WAF/Cloudflare blocks a direct `Dio` request, the app automatically falls back to a background `HeadlessInAppWebView` executing a same-origin `fetch()` inside the browser context.
3. **Original CRED NeoPop UI & Original Assets**: Uses the authentic assets extracted from the XAPK (`assets/toastr_logo.png`, `assets/bg_lights.png`, and `assets/svg/*`) paired with CRED's `neopop` button components.

---

## Option 1: Build Android `.apk` & iPhone `.ipa` for $0 via GitHub Actions (No Local Setup Needed)

Because you are on Windows and don't have a Mac or local Flutter SDK installed yet, this project includes [`.github/workflows/build_mobile.yml`](.github/workflows/build_mobile.yml) which uses GitHub's free Linux and macOS runners to compile both apps for $0:

1. Create a new repository on GitHub (public repositories get unlimited free macOS & Linux build minutes).
2. Push this project folder (`C:\Users\Vivek\.gemini\antigravity\scratch\toastr_app`) to GitHub:
   ```powershell
   cd C:\Users\Vivek\.gemini\antigravity\scratch\toastr_app
   git init
   git add .
   git commit -m "Initial commit: Serverless Toastr Flutter app"
   git branch -M main
   git remote add origin https://github.com/<your-username>/<your-repo>.git
   git push -u origin main
   ```
3. Go to the **Actions** tab of your GitHub repository. Within ~5 minutes, the workflow will produce two downloadable artifacts:
   - **`Toastr-Android-Release-APK`** (`app-release.apk`): Download and install directly on your Android phone.
   - **`Toastr-iOS-Unsigned-IPA`** (`Toastr-iOS-Unsigned.ipa`): Install on your iPhone from Windows for free using **[Sideloadly](https://sideloadly.io/)** or **[AltStore](https://altstore.io/)** with your free Apple ID.

---

## Option 2: Build Locally on Windows (For Android)

If you install the [Flutter SDK for Windows](https://docs.flutter.dev/get-started/install/windows/mobile), run:

```powershell
cd C:\Users\Vivek\.gemini\antigravity\scratch\toastr_app
flutter create --platforms=android,ios --org com.atinnovations .
flutter pub get
flutter run
```
