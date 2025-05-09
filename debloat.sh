#!/data/data/com.termux/files/usr/bin/bash
#
# Android Debloat for Termux
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

# === Generate Random Android Studio-compatible Code ===
generate_studio_code() {
  # Generate random characters for the name (following studio-XXXXXXX@ pattern)
  local chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789$"
  local name_random=""
  for i in {1..7}; do
    name_random+="${chars:$((RANDOM % ${#chars})):1}"
  done
  
  # Generate random password (following special character pattern)
  local pass_chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*<>?"
  local pass_random=""
  for i in {1..10}; do
    pass_random+="${pass_chars:$((RANDOM % ${#pass_chars})):1}"
  done
  
  echo "studio-${name_random}@" "${pass_random}!"
}

# === ADB Wi-Fi Setup ===
connect_wifi_adb() {
  echo "[*] Switching ADB to TCP/IP mode on port 5555..."
  adb tcpip 5555
  sleep 1
  DEVICE_IP=$(adb shell ip route | awk '{print $1}')
  if [[ -z "$DEVICE_IP" ]]; then
    echo "[!] Could not detect device IP. Is USB debugging enabled?"
    exit 1
  fi
  echo "[*] Device IP detected: $DEVICE_IP"
  adb disconnect
  adb connect "${DEVICE_IP}:5555"
  if [[ $? -ne 0 ]]; then
    echo "[!] ADB connection failed. Check Wi-Fi and developer settings."
    exit 1
  fi
  echo "[+] ADB connection established to ${DEVICE_IP}:5555"
}

# === Generate QR Code via Python ===
generate_qr() {
  local content="$1"
  echo "[*] QR Code (scan this on target device):"
  # Always attempt to use qrcode (we installed it in check_requirements)
  python - <<EOF
import qrcode
qr = qrcode.QRCode()
qr.add_data("$content")
qr.make()
qr.print_ascii(invert=True)
EOF
}

# === Filter and Disable System Apps ===
filter_apps() {
  read -p "Enter keyword to filter system apps: " keyword
  adb shell pm list packages -s | cut -d':' -f2 | grep -i "$keyword" > app_list.txt

  if [[ ! -s app_list.txt ]]; then
    echo "[!] No apps matched '$keyword'."
    read -p "Press Enter to return to menu."
    return
  fi

  nl -n ln -w 2 app_list.txt > numbered_app_list.txt
  clear
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
      adb shell pm disable-user --user 0 "$package" || echo "⚠️ Could not disable $package"
    fi
  done

  read -p "Press Enter to continue..."
}

# === Check and Install Requirements ===
check_requirements() {
  echo "[*] Checking and installing required packages..."
  
  # Check for Python
  if ! command -v python >/dev/null 2>&1; then
    echo "[*] Python not found. Installing..."
    install_python
  fi
  
  # Check for ADB
  if ! command -v adb >/dev/null 2>&1; then
    echo "[*] ADB not found. Installing android-tools..."
    pkg install -y android-tools
  fi
  
  echo "[+] All requirements satisfied"
}

# === Display Script Banner ===
show_banner() {
  clear
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
        # Generate unique Android Studio format QR code
        read NAME PASS < <(generate_studio_code)
        QR_CONTENT="WIFI:T:S:${NAME};P:${PASS};;"
        generate_qr "$QR_CONTENT"
        echo -e "\nPair using:\nName: $NAME\nPassword: $PASS"
        echo "[Developer options > Wireless debugging > Pair device with pairing code]"
        read -p "Press Enter when ready..."
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
        echo "[!] Invalid choice. Please enter a valid option (1-4)."
        sleep 2
        ;;
    esac
  done
}

# === RUN ===
check_requirements
main_menu
