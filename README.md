# PANDA AI STUDIO

**Your Voice. Your Intelligence.**

[![Android Build](https://github.com/surafel5509-del/Panda-Ai/actions/workflows/android-build.yml/badge.svg)](https://github.com/surafel5509-del/Panda-Ai/actions/workflows/android-build.yml)

A premium monochrome mobile app for the [Panda Voice AI](https://panda-voice-ai-production.up.railway.app) platform — AI text-to-speech and AI chat, built with **Flutter/Dart** for Android and iOS.

## Download the APK (CI-built)

Every push builds the app in GitHub Actions (`flutter analyze` + `flutter test` + release/debug APK):

1. Open [**Actions → Android Build**](https://github.com/surafel5509-del/Panda-Ai/actions/workflows/android-build.yml)
2. Click the latest ✅ successful run
3. Download the **`panda-ai-studio-apk`** artifact (bottom of the page)
4. Unzip — inside are `PandaAiStudio-1.0.0-release.apk` and `…-debug.apk`
5. Install on your Android device (allow "install from unknown sources" once)

> The release APK is signed with the debug key for easy installation.
> Add your own `key.properties` signing config before Play Store release.

<p align="center">
  <img src="ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png" width="160" alt="PANDA AI STUDIO icon">
</p>

---

## Features

| Area | What it does |
| --- | --- |
| **Home** | Hero dashboard, quick actions, live account/usage card (real API data only), recent generations and conversations |
| **Voice Studio** | Text editor (up to 4,000 chars), voice picker with search & gender filter, style chips, engine selection, speed (0.5–2.0×) and volume (−20…+20) sliders, MP3 voice preview, one-tap generation, waveform playback, share/export |
| **AI Chat** | Conversations with session continuation, typing indicator, suggestion chips, message copy, retry on failure, remote chat history with delete |
| **Library** | All generated MP3s persisted on-device: search, sort, play (waveform + progress), share, delete, storage stats |
| **Voice Library** | Browse every voice from the API, preview any voice as MP3, view voice details (GET `/voices/{id}`), select for the Studio |
| **Settings** | **API Token panel** (paste/save/show-hide/test connection/remove — masked display), custom API base URL, appearance (system/light/dark), default speed/volume/engine/voice, chat language, storage management, about/privacy/terms/help |

### Design

Strictly monochrome: only `#000000` and `#FFFFFF` with opacity variations. Inter typography, Material 3, floating bottom navigation, micro-animations (`flutter_animate`), animated waveforms, full dark/light/system theme support.

### API integration (real, no mocks)

Base URL: `https://panda-voice-ai-production.up.railway.app` · Auth: `X-API-Key` header.

`GET /health` · `GET /api/v1/voices` (+ filters) · `GET /api/v1/voices/{voice_id}` · `GET /api/v1/styles` · `GET /api/v1/engines` · `POST /api/v1/preview` (MP3) · `POST /api/v1/tts` (MP3) · `POST /api/v1/chat` · `POST /api/v1/chat/completions` · `GET /api/v1/chat/sessions` · `DELETE /api/v1/chat/sessions/{id}` · `GET /api/v1/account` · `GET /api/v1/limits` · `GET /api/v1/subscription`

MP3 endpoints are handled as **binary audio** and validated (ID3 / MPEG frame-sync) before playback or saving — an error body is never treated as audio.

### Security

- The API token is **entered by the user** in *Settings → API Token* and stored only in the **device secure store** (iOS Keychain / Android Keystore via `flutter_secure_storage`). It is never hard-coded, never committed, never written to plain preferences or logs.
- HTTPS only (no arbitrary loads on iOS).
- `.gitignore` blocks `.env`, keystores and other secret files.

---

## Project structure

```
lib/
├── main.dart                        # Entry point: services + providers wiring
├── app.dart                         # MaterialApp, theme mode, shell
├── core/
│   ├── constants/api_config.dart    # Endpoints, keys, TTS constraints
│   ├── theme/app_theme.dart         # Monochrome light/dark design system
│   └── utils/                       # Typed exceptions, formatters
├── data/
│   ├── models/models.dart           # Defensive JSON models
│   └── services/
│       ├── api_service.dart         # HTTP client (X-API-Key, binary MP3)
│       ├── storage_service.dart     # Secure token + preferences
│       ├── audio_player_service.dart# Shared audio player + streams
│       └── library_service.dart     # On-device MP3 persistence
└── presentation/
    ├── providers/                   # ChangeNotifier state (provider)
    ├── screens/                     # Home, Studio, Chat, Library, Voices, Settings
    └── widgets/                     # Shell, waveform, empty/error states…
tool/generate_icons.py               # Regenerates launcher & launch icons
```

## Getting started

### 1. Install Flutter

Install Flutter **3.29 or newer** (Dart ≥ 3.7): https://docs.flutter.dev/get-started/install

Verify: `flutter doctor`

### 2. Get dependencies

```bash
flutter pub get
```

> The Android and iOS platform folders are already complete and committed
> (Gradle wrapper, Xcode project, assets). If you ever need to regenerate
> them, run `flutter create .` in the project root — it does not touch
> `lib/` or `pubspec.yaml`.

### 3. Run

```bash
# Android emulator / device
flutter run

# iOS simulator / device (macOS)
cd ios && pod install && cd ..
flutter run
```

### 4. Add your API token

1. Open the app → **Settings**
2. In the **API TOKEN** card, paste your Panda Voice AI token
3. Tap **Save token**, then **Test connection**
4. Voices, speech generation and chat are now unlocked

Without a token the app still launches, but API-backed features ask you to add one.

## Building for release

```bash
# Android APK (debug-signed; add your own signing config for store release)
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS (requires Xcode + signing)
flutter build ipa --release
```

## Tests & checks

```bash
flutter analyze
flutter test
python3 tool/generate_icons.py   # regenerate icons (stdlib only)
```

## Troubleshooting

| Problem | Fix |
| --- | --- |
| “Voices unavailable” | Settings → API Token → **Test connection**; check internet |
| 401 errors | Token invalid/expired — paste a fresh token and save |
| `flutter.sdk not set in local.properties` | Run `flutter pub get` once (it writes `android/local.properties`) |
| iOS pods fail | `cd ios && pod repo update && pod install` |
| Icons look default | `python3 tool/generate_icons.py` then rebuild |

## License

Proprietary — © PANDA AI STUDIO. All rights reserved.
