#!/bin/bash
set -e

# ==============================================================================
# Fortinet Captive Portal Auto-Login Uninstaller (Cross-Platform)
# ==============================================================================

OS_TYPE="$(uname -s)"
echo "Fortinet Autologin Kaldirma Islemi Baslatiliyor ($OS_TYPE)..."

case "$OS_TYPE" in
    Darwin)
        PLIST_FILE="$HOME/Library/LaunchAgents/com.user.fortinet-autologin.plist"
        TARGET_BIN="$HOME/.local/bin/fortinet-autologin"

        if [ -f "$PLIST_FILE" ]; then
            launchctl unload "$PLIST_FILE" 2>/dev/null || true
            rm -f "$PLIST_FILE"
            echo "launchd servisi durduruldu ve kaldirildi."
        fi

        rm -f "$TARGET_BIN"
        echo "Calistirilabilir dosya silindi: $TARGET_BIN"
        echo "Not: Guvenlik nedeniyle macOS Keychain kaydi silinmemistir. Isterseniz 'security delete-generic-password -s fortinet-portal' ile silebilirsiniz."
        echo "Kaldirma islemi tamamlandi."
        ;;

    Linux)
        if [ "$EUID" -ne 0 ]; then
            echo "Hata: Kaldirma islemi root (sudo) yetkisi gerektirir."
            echo "Kullanim: sudo ./uninstall.sh"
            exit 1
        fi

        systemctl stop fortinet-autologin.timer 2>/dev/null || true
        systemctl disable fortinet-autologin.timer 2>/dev/null || true

        rm -f /etc/systemd/system/fortinet-autologin.service
        rm -f /etc/systemd/system/fortinet-autologin.timer
        systemctl daemon-reload

        rm -f /usr/local/bin/fortinet-autologin
        rm -rf /etc/fortinet-autologin

        echo "Tum systemd servisleri, calistirilabilir dosya ve yapilandirmalar kaldirildi."
        ;;

    CYGWIN*|MINGW*|MSYS*)
        echo "Windows / MINGW ortami algilandi."
        if command -v powershell.exe >/dev/null 2>&1; then
            powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(dirname "$0")/uninstall.ps1"
        else
            echo "Lutfen PowerShell uzerinden su komutu calistiriniz:"
            echo "powershell -ExecutionPolicy Bypass -File uninstall.ps1"
        fi
        ;;

    *)
        echo "Desteklenmeyen isletim sistemi: $OS_TYPE"
        exit 1
        ;;
esac
