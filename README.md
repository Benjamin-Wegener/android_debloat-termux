# Android Debloat Tool for Termux

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Android-brightgreen.svg" alt="Platform Android">
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT License">
  <img src="https://img.shields.io/badge/Version-1.0.0-orange.svg" alt="Version 1.0.0">
</p>

<p align="center">
  <b>Remove bloatware from your Android device easily using Termux</b>
</p>

---

## ✨ Features

- 📱 Connect to your Android device wirelessly via ADB
- 🔎 Search and filter system applications
- 🗑️ Disable unwanted bloatware with a few taps
- 🔄 Generates unique QR codes compatible with Android Studio wireless debugging
- 📋 Simple and intuitive menu interface
- 📦 Auto-installs all required dependencies

## 📋 Requirements

- Android device with [Developer Options](https://developer.android.com/studio/debug/dev-options) and USB debugging enabled
- [Termux](https://f-droid.org/en/packages/com.termux/) installed from F-Droid

## ⚡ One-Line Installation

```bash
curl -L https://raw.githubusercontent.com/Benjamin-Wegener/android_debloat-termux/main/debloat.sh | bash
```

## 🚀 Usage

1. Connect your Android device to your computer via USB
2. Enable USB debugging on your device
3. Run the script in Termux:
   ```bash
   ./debloat.sh
   ```
4. Choose an option from the menu:
   - Generate a QR code for wireless ADB pairing
   - Connect to your device wirelessly
   - Search and disable system apps

## 🧰 How It Works

The tool provides a streamlined process to:

1. **Set up wireless debugging** - Generate a unique QR code that can be scanned from your Android device's Developer Options
2. **Connect wirelessly** - Switch ADB from USB to Wi-Fi, allowing you to disconnect the cable
3. **Filter system apps** - Search for unwanted apps by keyword
4. **Disable bloatware** - Disable selected system apps without root access

## 📸 Screenshots

<p align="center">
  <i>Coming soon</i>
</p>

## ⚠️ Warning

- This tool only disables applications, it doesn't uninstall them
- Disabling system apps may cause unexpected behavior
- You can re-enable apps through Settings > Apps > All Apps if needed

## 🔄 Restoring Apps

If you need to re-enable an app:

1. Go to Settings > Apps > All Apps
2. Find the disabled app
3. Tap "Enable"

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Benjamin Wegener**

- GitHub: [Benjamin-Wegener](https://github.com/Benjamin-Wegener)

---

<p align="center">
  <i>If you find this tool useful, please consider giving it a star ⭐</i>
</p>
