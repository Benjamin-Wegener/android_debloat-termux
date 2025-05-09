#!/data/data/com.termux/files/usr/bin/bash
# Android Debloat Tool (Termux)
# https://github.com/Benjamin-Wegener/android_debloat-termux
# MIT License

# === Install Python and Dependencies ===
install_python() {
  echo "[*] Installing Python, pip, and OpenSSL..."
  pkg install -y python openssl
  python -m ensurepip --upgrade
  pip install --upgrade pip setuptools wheel
  pip install qrcode
  echo "[+] Python installation complete"
}

# === Generate Android Studio-compatible Credentials ===
generate_studio_code() {
  local chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789$"
  local pass_chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*<>?"

  local name_random=""
  for i in {1..7}; do
    name_random+="${chars:$((RANDOM % ${#chars})):1}"
  done

  local pass_random=""
  for i in {1..10}; do
    pass_random+="${pass_chars:$((RANDOM % ${#pass_chars})):1}"
  done

  echo "studio-${name_random}@" "${pass_random}!"
}

# === ADB Wi-Fi Setup ===
connect_wifi_adb() {
  echo "[*] Switching ADB to TCP/IP mode on port 5555..."
  adb tcpip 5555 >> adb_log.txt 2>&1
  sleep 1
  DEVICE_IP=$(adb shell ip route | awk '{print $9}' | head -n1)
  if [[ -z "$DEVICE_IP" ]]; then
    echo "[!] Could not detect device IP. Is USB debugging enabled?"
    return
  fi
  echo "[*] Device IP detected: $DEVICE_IP"
  adb disconnect >> adb_log.txt 2>&1
  adb connect "${DEVICE_IP}:5555" >> adb_log.txt 2>&1
  if [[ $? -ne 0 ]]; then
    echo "[!] ADB connection failed. Check Wi-Fi and developer settings."
    return
  fi
  echo "[+] ADB connection established to ${DEVICE_IP}:5555"
}

# === Generate and Wait for QR Code Pairing ===
generate_qr_simple() {
  local content="$1"
  echo "[*] QR Code (scan this on target device):"
  python - <<EOF
import qrcode
qr = qrcode.QRCode()
qr.add_data("$content")
qr.make()
qr.print_ascii(invert=True)
EOF

  echo "Pair using:"
  echo "Name: debug"
  echo "Password: 123456"
  echo "[Developer options > Wireless debugging > Pair device with QR code]"
  echo "[*] Waiting up to 60 seconds for ADB connection after scan..."

  for i in {1..60}; do
    sleep 1
    adb_output=$(adb devices | awk 'NR>1')

    if echo "$adb_output" | grep -q "device$"; then
      connected=$(echo "$adb_output" | awk '$2=="device" {print $1}')
      echo "[+] Device connected: $connected"
      break
    elif echo "$adb_output" | grep -q "unauthorized$"; then
      problem=$(echo "$adb_output" | awk '$2=="unauthorized" {print $1}')
      echo "[!] Device unauthorized: $problem"
      echo "    ➤ Accept the ADB prompt on your device."
    elif echo "$adb_output" | grep -q "offline$"; then
      problem=$(echo "$adb_output" | awk '$2=="offline" {print $1}')
      echo "[!] Device offline: $problem"
      echo "    ➤ Try disabling/re-enabling wireless debugging."
    fi

    if (( i % 10 == 0 )); then
      echo "[*] Still waiting... ($i seconds elapsed)"
    fi
  done

  if [[ -z "$connected" ]]; then
    echo "[!] No device fully connected after 60 seconds."
  fi

  read -p "Press Enter to return to menu..."
}

# === Filter and Disable System Apps ===
filter_apps() {
  read -p "Enter keyword to filter system apps: " keyword
  adb shell pm list packages -s | cut -d':' -f2 | grep -i "$keyword" > app_list.txt

  if [[ ! -s app_list.txt ]]; then
    echo "[!] No apps matched '$keyword'."
    read -p "Press Enter to return to menu..."
    return
  fi

  nl -n ln -w 2 app_list.txt > numbered_app_list.txt
  echo "Filtered system apps matching '$keyword':"
  cat numbered_app_list.txt

  echo -e "\nEnter space-separated numbers to disable apps (or 'b' to go back):"
  read -a selections

  if [[ "${selections[0]}" == "b" ]]; then
    return
  fi

  for sel in "${selections[@]}"; do
    if [[ "$sel" =~ ^[0-9]+$ ]]; then
      package=$(sed -n "${sel}p" app_list.txt)
      echo "Disabling: $package"
      adb shell pm disable-user --user 0 "$package" >> adb_log.txt 2>&1 ||         echo "⚠️ Could not disable $package"
    fi
  done

  read -p "Press Enter to continue..."
}

# === Check and Install Requirements ===
check_requirements() {
  echo "[*] Checking and installing required packages..."

  if ! command -v python >/dev/null 2>&1; then
    echo "[*] Python not found. Installing..."
    install_python
  fi

  if ! command -v adb >/dev/null 2>&1; then
    echo "[*] ADB not found. Installing android-tools..."
    pkg install -y android-tools
  fi

  echo "[+] All requirements satisfied"
}

# === Banner Display ===
show_banner() {
  echo -e "\033[1;36m╔═════════════════════════════════════════════════╗\033[0m"
  echo -e "\033[1;36m║                                                 ║\033[0m"
  echo -e "\033[1;36m║  \033[1;33mAndroid Debloat Tool\033[1;36m                        ║\033[0m"
  echo -e "\033[1;36m║  \033[0;37mWireless ADB + System App Disabler\033[1;36m          ║\033[0m"
  echo -e "\033[1;36m║                                                 ║\033[0m"
  echo -e "\033[1;36m║  \033[0;37mBy Benjamin Wegener\033[1;36m                         ║\033[0m"
  echo -e "\033[1;36m║  \033[0;37mhttps://github.com/Benjamin-Wegener\033[1;36m         ║\033[0m"
  echo -e "\033[1;36m╚═════════════════════════════════════════════════╝\033[0m"
  echo ""
}

# === Main Menu ===
main_menu() {
  while true; do
    show_banner
    echo -e "\033[1;37m=== MAIN MENU ===\033[0m"
    echo -e "\033[1;34m1)\033[0m Generate ADB pairing QR code"
    echo -e "\033[1;34m2)\033[0m Connect to device via Wi-Fi"
    echo -e "\033[1;34m3)\033[0m Filter and disable system apps"
    echo -e "\033[1;34m4)\033[0m Exit"
    echo ""
    read -p "Select an option (1-4): " choice

    case "$choice" in
      1)
        QR_CONTENT="WIFI:T:ADB;S:debug;P:123456;;"
        generate_qr_simple "$QR_CONTENT"
        ;;
      2)
        connect_wifi_adb
        read -p "Press Enter to return to menu..."
        ;;
      3)
        filter_apps
        ;;
      4)
        echo "Exiting Android Debloat Tool. Goodbye!"
        break
        ;;
      *)
        echo "[!] Invalid choice. Please enter 1-4."
        sleep 2
        ;;
    esac
  done
}

# === Start Script ===
echo -e "\033[1;32m[*] Starting Android Debloat Tool...\033[0m"
check_requirements
main_menu
