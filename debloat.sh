#!/data/data/com.termux/files/usr/bin/bash

# Android Debloat Tool (Termux) - Manual Pairing Version
# https://github.com/Benjamin-Wegener/android_debloat-termux 
# MIT License
# Modified by AI to use manual ADB pairing without QR codes

# Global variable to store last search keyword
last_keyword=""

# === Menu Options ===
show_menu() {
    clear
    echo "=== ANDROID DEBLOAT TOOL ==="
    echo "1. Connect Device via Wi-Fi (Manual Pairing)"
    echo "2. List Connected Devices"
    echo "3. Disable System Apps"
    echo "4. Enable Disabled Apps"
    echo "5. Exit"
    echo "==========================="
}

# === Install Required Tools ===
install_dependencies() {
    echo "[*] Installing required tools..."
    pkg install -y openssh readline-utils net-tools > /dev/null 2>&1
    echo "[+] Dependencies installed."
}

# === Connect Device via Manual ADB Wi-Fi Pairing ===
connect_wifi_adb_manual() {
    echo ""
    echo "[*] Please follow these steps:"
    echo "1. On your Android device, go to Settings > Developer options > Wireless debugging"
    echo "2. Tap 'Pair device with pairing code'"
    echo ""

    read -p "Enter device IP address: " DEVICE_IP
    read -p "Enter pairing port (default is 5555): " PAIRING_PORT
    read -p "Enter 6-digit pairing code: " PAIRING_CODE

    # Set default port if empty
    PAIRING_PORT=${PAIRING_PORT:-5555}

    echo "[*] Attempting to pair with $DEVICE_IP:$PAIRING_PORT using code $PAIRING_CODE..."
    adb pair $DEVICE_IP:$PAIRING_PORT $PAIRING_CODE

    echo "[*] Checking output for connection port..."

    # Capture the output of the pairing command
    CONNECT_OUTPUT=$(adb pair $DEVICE_IP:$PAIRING_PORT $PAIRING_CODE 2>&1)

    if [[ "$CONNECT_OUTPUT" == *"use 'adb connect"* ]]; then
        # Try to extract the full address with port
        CONNECT_ADDRESS=$(echo "$CONNECT_OUTPUT" | grep -o "adb connect [0-9.]*:[0-9]*" | head -n1 | cut -d' ' -f3)
        if [[ -n "$CONNECT_ADDRESS" ]]; then
            echo "[+] Found connection address: $CONNECT_ADDRESS"
            echo "[*] Connecting using extracted address..."
            adb connect $CONNECT_ADDRESS
        else
            echo "[!] Could not auto-detect connection port."
            read -p "Please enter connection port manually: " CONNECTION_PORT
            adb connect $DEVICE_IP:$CONNECTION_PORT
        fi
    else
        echo "[!] Pairing may have failed or no connection port returned."
        read -p "Please enter connection port manually: " CONNECTION_PORT
        adb connect $DEVICE_IP:$CONNECTION_PORT
    fi

    echo ""
    echo "[*] Final connection status:"
    adb devices -l
}

# === List Connected Devices ===
list_devices() {
    echo ""
    echo "== CONNECTED DEVICES =="
    adb devices -l
    echo ""
    read -p "Press Enter to continue..."
}

# === Filter and Disable System Apps ===
filter_apps() {
    # First check if device is connected
    if ! adb get-state &>/dev/null; then
        echo "[!] No device connected. Please connect to a device first."
        read -p "Press Enter to return to menu..."
        return
    fi

    read -p "Enter keyword to filter system apps (leave empty to list all) [Last: ${last_keyword:-none}]: " keyword
    [[ -n "$keyword" ]] && last_keyword="$keyword"

    echo "[*] Retrieving system packages..."

    if [[ -z "$keyword" ]]; then
        adb shell pm list packages -s | cut -d':' -f2 > app_list.txt
    else
        adb shell pm list packages -s | cut -d':' -f2 | grep -i "$keyword" > app_list.txt
    fi

    if [[ ! -s app_list.txt ]]; then
        echo "[!] No apps matched '$keyword'."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Sort alphabetically for easier browsing
    sort app_list.txt > sorted_app_list.txt
    mv sorted_app_list.txt app_list.txt

    while true; do
        clear
        echo -e "\nFiltered system apps${keyword:+ matching '$keyword'}:"
        nl -n ln -w 2 app_list.txt

        echo -e "\nOptions:"
        echo "  * Enter number to disable app"
        echo "  * Type 'all' to disable all listed apps"
        echo "  * Type 'b' to go back to main menu"
        echo "  * Press Enter to refresh list"
        read -p "> " selection

        if [[ "$selection" == "b" ]]; then
            break
        elif [[ "$selection" == "all" ]]; then
            echo "[!] Are you sure you want to disable ALL listed apps?"
            read -p "Type 'confirm' to proceed: " confirm
            if [[ "$confirm" == "confirm" ]]; then
                total=$(wc -l < app_list.txt)
                current=0
                while read package; do
                    current=$((current + 1))
                    echo -ne "Disabling [$current/$total]: $package\r"
                    adb shell pm disable-user --user 0 "$package" >> adb_log.txt 2>&1
                done < app_list.txt
                echo -e "\n[+] Disabled all $total packages."
                read -p "Press Enter to continue..."
            fi
        elif [[ "$selection" =~ ^[0-9]+$ ]]; then
            package=$(sed -n "${selection}p" app_list.txt)
            if [[ -n "$package" ]]; then
                echo "Disabling: $package"
                result=$(adb shell pm disable-user --user 0 "$package" 2>&1)
                if [[ "$result" == *"new state: disabled-user"* ]]; then
                    echo "✅ Disabled successfully"
                else
                    echo "⚠️ Could not disable - might require root or is system critical"
                fi
                read -p "Press Enter to return to the same list..."
            else
                echo "⚠️ Invalid selection"
                sleep 1
            fi
        elif [[ -z "$selection" ]]; then
            continue
        else
            echo "⚠️ Invalid input"
            sleep 1
        fi
    done
}

# === Enable Previously Disabled Apps ===
enable_apps() {
    # First check if device is connected
    if ! adb get-state &>/dev/null; then
        echo "[!] No device connected. Please connect to a device first."
        read -p "Press Enter to return to menu..."
        return
    fi

    read -p "Enter keyword to filter disabled apps (leave empty to list all): " keyword
    echo "[*] Retrieving disabled packages..."

    if [[ -z "$keyword" ]]; then
        adb shell pm list packages -d | cut -d':' -f2 > disabled_list.txt
    else
        adb shell pm list packages -d | cut -d':' -f2 | grep -i "$keyword" > disabled_list.txt
    fi

    if [[ ! -s disabled_list.txt ]]; then
        echo "[!] No disabled apps matched '$keyword'."
        read -p "Press Enter to return to menu..."
        return
    fi

    # Sort alphabetically for easier browsing
    sort disabled_list.txt > sorted_disabled_list.txt
    mv sorted_disabled_list.txt disabled_list.txt

    while true; do
        clear
        echo -e "\nDisabled apps${keyword:+ matching '$keyword'}:"
        nl -n ln -w 2 disabled_list.txt

        echo -e "\nOptions:"
        echo "  * Enter number to enable app"
        echo "  * Type 'all' to enable all listed apps"
        echo "  * Type 'b' to go back to main menu"
        echo "  * Press Enter to refresh list"
        read -p "> " selection

        if [[ "$selection" == "b" ]]; then
            break
        elif [[ "$selection" == "all" ]]; then
            echo "[!] Are you sure you want to enable ALL listed apps?"
            read -p "Type 'confirm' to proceed: " confirm
            if [[ "$confirm" == "confirm" ]]; then
                total=$(wc -l < disabled_list.txt)
                current=0
                while read package; do
                    current=$((current + 1))
                    echo -ne "Enabling [$current/$total]: $package\r"
                    adb shell pm enable "$package" --user 0 >> adb_log.txt 2>&1
                done < disabled_list.txt
                echo -e "\n[+] Enabled all $total packages."
                read -p "Press Enter to continue..."
            fi
        elif [[ "$selection" =~ ^[0-9]+$ ]]; then
            package=$(sed -n "${selection}p" disabled_list.txt)
            if [[ -n "$package" ]]; then
                echo "Enabling: $package"
                result=$(adb shell pm enable "$package" --user 0 2>&1)
                if [[ "$result" == *"enabled"* ]]; then
                    echo "✅ Enabled successfully"
                else
                    echo "⚠️ Could not enable - might be system protected"
                fi
                read -p "Press Enter to return to the same list..."
            else
                echo "⚠️ Invalid selection"
                sleep 1
            fi
        elif [[ -z "$selection" ]]; then
            continue
        else
            echo "⚠️ Invalid input"
            sleep 1
        fi
    done
}

# === Main Loop ===
main() {
    install_dependencies

    while true; do
        show_menu
        read -p "Select option [1-5]: " choice
        case "$choice" in
            1)
                connect_wifi_adb_manual
                ;;
            2)
                list_devices
                ;;
            3)
                filter_apps
                ;;
            4)
                enable_apps
                ;;
            5)
                echo "[+] Exiting script. Goodbye!"
                exit 0
                ;;
            *)
                echo "[!] Invalid option. Please try again."
                sleep 1
                ;;
        esac
    done
}

# Run main function
main
