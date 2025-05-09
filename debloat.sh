#!/data/data/com.termux/files/usr/bin/bash
# Android Debloat Tool (Termux)
# https://github.com/Benjamin-Wegener/android_debloat-termux
# MIT License
#
# Using pairing code from:
# https://gist.github.com/benigumocom/a6a87fc1cb690c3c4e3a7642ebf2be6f
# and Python-zeroconf library:
# https://github.com/jstasiak/python-zeroconf

# === Install Python and Dependencies ===
install_python() {
  echo "[*] Installing Python, pip, and OpenSSL..."
  pkg install -y python openssl
  python -m ensurepip --upgrade
  pip install --upgrade pip setuptools wheel
  pip install qrcode zeroconf
  echo "[+] Python installation complete"
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

# === Generate and Wait for QR Code Pairing with Python ===
generate_qr_python() {
  # Create a Python script file
  cat > adb_pairing.py << 'EOF'
"""
Android11+ Wireless Debug Pairing
Optimized code for ADB wireless debugging pairing via QR code

Based on original code from:
https://gist.github.com/benigumocom/a6a87fc1cb690c3c4e3a7642ebf2be6f

Using python-zeroconf for service discovery:
https://github.com/jstasiak/python-zeroconf
"""

import subprocess
import sys
import time
from zeroconf import ServiceBrowser, Zeroconf
import logging
import signal

# Configuration
SERVICE_TYPE = "_adb-tls-pairing._tcp.local."
PAIRING_NAME = "debug"
PAIRING_PASSWORD = "123456"
QR_FORMAT = "WIFI:T:ADB;S:%s;P:%s;;"

# Define commands
CMD_PAIR_DEVICE = "adb pair %s:%s %s"
CMD_LIST_DEVICES = "adb devices -l"

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger('adb-pairing')

class AdbPairingListener:
    """Zeroconf listener for ADB pairing services."""
    
    def __init__(self):
        self.paired = False
    
    def remove_service(self, zeroconf, type, name):
        logger.info(f"Service {name} removed")
    
    def add_service(self, zeroconf, type, name):
        # Get service info
        info = zeroconf.get_service_info(type, name)
        if not info:
            logger.warning("Failed to get service info")
            return
            
        logger.info(f"Discovered ADB pairing service: {name}")
        logger.debug(f"Service details: {info}")
        
        self.pair_device(info)
    
    def pair_device(self, info):
        """Attempt to pair with the discovered ADB device."""
        try:
            # Extract server and port
            server = info.server
            port = info.port
            
            # Execute pairing command
            pairing_cmd = CMD_PAIR_DEVICE % (server, port, PAIRING_PASSWORD)
            logger.info(f"Executing: {pairing_cmd}")
            
            result = subprocess.run(pairing_cmd, shell=True, 
                                   capture_output=True, text=True)
            
            # Check pairing result
            if result.returncode == 0 and "Successfully paired" in result.stdout:
                logger.info("✅ Device paired successfully!")
                self.paired = True
            else:
                logger.error("❌ Pairing failed")
                if result.stderr:
                    logger.error(f"Error: {result.stderr}")
                
        except Exception as e:
            logger.error(f"Error during pairing: {str(e)}")


def handle_interrupt(signum, frame):
    """Handle keyboard interrupt gracefully."""
    logger.info("\nPairing process interrupted")
    list_connected_devices()
    sys.exit(0)


def list_connected_devices():
    """List all connected ADB devices."""
    logger.info("\n=== CONNECTED DEVICES ===")
    subprocess.run(CMD_LIST_DEVICES, shell=True)


def generate_qr_code():
    """Generate and display QR code for ADB pairing."""
    try:
        # Using the original QR code generation method that works
        text = QR_FORMAT % (PAIRING_NAME, PAIRING_PASSWORD)
        
        # Use Python's qrcode library that we know works
        import qrcode
        qr = qrcode.QRCode()
        qr.add_data(text)
        qr.make()
        qr.print_ascii(invert=True)
        
        return True
    except Exception as e:
        logger.error(f"Failed to generate QR code: {str(e)}")
        return False


def main():
    """Main entry point for ADB pairing."""
    # Register signal handler for clean exit
    signal.signal(signal.SIGINT, handle_interrupt)
    
    # Display instructions
    print("\n=== ADB WIRELESS DEBUGGING PAIRING ===")
    print("1. On your Android device, go to:")
    print("   Settings > Developer options > Wireless debugging")
    print("2. Select 'Pair device with QR code'")
    print("3. Scan the QR code below\n")
    
    # Generate and display QR code
    if not generate_qr_code():
        return 1
    
    print("\nPair using:")
    print(f"Name: {PAIRING_NAME}")
    print(f"Password: {PAIRING_PASSWORD}")
        
    print("\nWaiting for pairing request...\n")
    
    try:
        # Setup Zeroconf service browser
        zeroconf = Zeroconf()
        listener = AdbPairingListener()
        browser = ServiceBrowser(zeroconf, SERVICE_TYPE, listener)
        
        # Wait for pairing or user interrupt
        timeout = 120  # 2 minutes timeout
        start_time = time.time()
        
        while not listener.paired and time.time() - start_time < timeout:
            time.sleep(1)
            
        if listener.paired:
            print("\nDevice successfully paired! You can now connect wirelessly.")
        else:
            print("\nPairing timed out after 2 minutes.")
            
        # List devices after pairing
        list_connected_devices()
            
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return 1
    finally:
        print("\nPress Enter to return to menu...")
        input()
        zeroconf.close()
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
EOF

  echo "[*] Starting ADB pairing with QR code..."
  python adb_pairing.py
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
  
  # Check for Python packages
  if ! python -c "import zeroconf" 2>/dev/null; then
    echo "[*] Python zeroconf package not found. Installing..."
    pip install zeroconf
  fi

  echo "[+] All requirements satisfied"
}

# === Banner Display ===
show_banner() {
  echo -e "\033[1;36m╔════════════════════════════════════════════╗\033[0m"
  echo -e "\033[1;36m║                                            ║\033[0m"
  echo -e "\033[1;36m║  \033[1;33mAndroid Debloat Tool\033[1;36m                     ║\033[0m"
  echo -e "\033[1;36m║  \033[0;37mWireless ADB + System App Disabler\033[1;36m       ║\033[0m"
  echo -e "\033[1;36m║                                            ║\033[0m"
  echo -e "\033[1;36m║  \033[0;37mBy Benjamin Wegener\033[1;36m                      ║\033[0m"
  echo -e "\033[1;36m║  \033[0;37mhttps://github.com/Benjamin-Wegener\033[1;36m      ║\033[0m"
  echo -e "\033[1;36m╚════════════════════════════════════════════╝\033[0m"
  echo ""
}

# === Main Menu ===
main_menu() {
  while true; do
    show_banner
    echo -e "\033[1;37m=== MAIN MENU ===\033[0m"
    echo -e "\033[1;34m1)\033[0m Generate ADB pairing QR code (Python)"
    echo -e "\033[1;34m2)\033[0m Connect to device via Wi-Fi"
    echo -e "\033[1;34m3)\033[0m Filter and disable system apps"
    echo -e "\033[1;34m4)\033[0m Exit"
    echo ""
    read -p "Select an option (1-4): " choice

    case "$choice" in
      1)
        generate_qr_python
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
