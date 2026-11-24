#!/bin/bash
set -e

# ==============================================================================
# Fortinet Captive Portal Auto-Login Installer (Cross-Platform: Linux, macOS, Windows)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS_TYPE="$(uname -s)"

echo "Fortinet Autologin Kurulum Sihirbazi Baslatiliyor..."
echo "Isletim Sistemi: $OS_TYPE"

# ------------------------------------------------------------------------------
# 1. macOS Kurulum Mantigi (launchd)
# ------------------------------------------------------------------------------
install_macos() {
    echo "macOS platformu algilandi."

    TARGET_BIN="$HOME/.local/bin/fortinet-autologin"
    PLIST_DIR="$HOME/Library/LaunchAgents"
    PLIST_FILE="$PLIST_DIR/com.user.fortinet-autologin.plist"

    mkdir -p "$HOME/.local/bin"
    cp "$SCRIPT_DIR/fortinet-autologin.sh" "$TARGET_BIN"
    chmod 755 "$TARGET_BIN"

    # Anahtar Zinciri (Keychain) kontrolu
    if ! security find-generic-password -s fortinet-portal >/dev/null 2>&1; then
        echo ""
        echo "macOS Keychain (Anahtar Zinciri) kaydi bulunamadi."
        echo "Lutfen FortiGate portal kullanici bilgilerinizi giriniz:"
        read -rp "Kullanici Adi: " mac_user
        read -rsp "Sifre: " mac_pass
        echo ""

        security add-generic-password -a "$mac_user" -s fortinet-portal -w "$mac_pass" -U
        echo "Bilgiler 'fortinet-portal' etiketiyle Keychain'e guvenle kaydedildi."
    else
        echo "Keychain uzerinde 'fortinet-portal' kaydi mevcut, korundu."
    fi

    mkdir -p "$PLIST_DIR"
    cat <<EOF > "$PLIST_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.fortinet-autologin</string>
    <key>ProgramArguments</key>
    <array>
        <string>$TARGET_BIN</string>
    </array>
    <key>StartInterval</key>
    <integer>60</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/fortinet-autologin.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/fortinet-autologin.log</string>
</dict>
</plist>
EOF

    # launchctl ile servisi yukle
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    launchctl load "$PLIST_FILE"

    echo ""
    echo "Kurulum tamamlandi."
    echo "Servis launchd tarafindan her dakika calistirilmak uzere baslatildi."
    echo "Log takibi: tail -f ~/Library/Logs/fortinet-autologin.log"
}

# ------------------------------------------------------------------------------
# 2. Linux Kurulum Mantigi (systemd)
# ------------------------------------------------------------------------------
install_linux() {
    echo "Linux platformu algilandi."

    if [ "$EUID" -ne 0 ]; then
        echo "Hata: Linux sistemlerde kurulum root (sudo) yetkisi gerektirir."
        echo "Lutfen tekrar calistirin: sudo ./install.sh"
        exit 1
    fi

    if ! command -v curl >/dev/null 2>&1; then
        echo "Hata: 'curl' komutu bulunamadi. Lutfen oncelikle curl paketini kurunuz."
        exit 1
    fi

    BIN_PATH="/usr/local/bin/fortinet-autologin"
    CONF_DIR="/etc/fortinet-autologin"
    CONF_FILE="$CONF_DIR/config.env"
    SYSTEMD_DIR="/etc/systemd/system"

    echo "[1/4] Calistirilabilir dosya kopyalaniyor: $BIN_PATH"
    cp "$SCRIPT_DIR/fortinet-autologin-linux.sh" "$BIN_PATH"
    chmod 755 "$BIN_PATH"

    echo "[2/4] Yapilandirma dosyasi kontrol ediliyor..."
    mkdir -p "$CONF_DIR"
    chmod 700 "$CONF_DIR"

    if [ ! -f "$CONF_FILE" ]; then
        echo ""
        echo "Lutfen FortiGate portal giris bilgilerinizi giriniz:"
        read -rp "Kullanici Adi: " input_user
        read -rsp "Sifre: " input_pass
        echo ""

        cat <<EOF > "$CONF_FILE"
# FortiGate Giris Bilgileri
FORTINET_USER="$input_user"
FORTINET_PASS="$input_pass"
EOF
        chmod 600 "$CONF_FILE"
        echo "Giris bilgileri $CONF_FILE dosyasina kaydedildi (Erisim izni: 600)."
    else
        echo "Mevcut yapilandirma dosyasi korundu: $CONF_FILE"
    fi

    echo "[3/4] Systemd servis ve timer dosyalari olusturuluyor..."

    cat <<EOF > "$SYSTEMD_DIR/fortinet-autologin.service"
[Unit]
Description=Fortinet Captive Portal Auto Login Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$BIN_PATH
EOF

    cat <<EOF > "$SYSTEMD_DIR/fortinet-autologin.timer"
[Unit]
Description=Fortinet Captive Portal Check Every Minute

[Timer]
OnBootSec=30s
OnUnitActiveSec=1m
Unit=fortinet-autologin.service

[Install]
WantedBy=timers.target
EOF

    echo "[4/4] Servisler etkinlestiriliyor..."
    systemctl daemon-reload
    systemctl enable --now fortinet-autologin.timer

    echo ""
    echo "Kurulum basariyla tamamlandi."
    echo "Zamanlayici aktif: her dakika baglanti kontrol edilecek ve gerekirse giris yapilacaktir."
    echo "Servis durumu: systemctl status fortinet-autologin.timer"
    echo "Canli log takibi: journalctl -u fortinet-autologin.service -f"
}

# ------------------------------------------------------------------------------
# 3. Windows Kurulum Yonlendirmesi (Git Bash / MSYS2 / WSL)
# ------------------------------------------------------------------------------
install_windows() {
    echo "Windows / MINGW ortami algilandi."
    if command -v powershell.exe >/dev/null 2>&1; then
        echo "PowerShell uzerinden Windows kurulum betigi (install.ps1) calistiriliyor..."
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/install.ps1"
    else
        echo "Lutfen PowerShell veya CMD uzerinden su komutu calistiriniz:"
        echo "powershell -ExecutionPolicy Bypass -File install.ps1"
    fi
}

# ------------------------------------------------------------------------------
# Ana Yonlendirici
# ------------------------------------------------------------------------------
case "$OS_TYPE" in
    Darwin)
        install_macos
        ;;
    Linux)
        install_linux
        ;;
    CYGWIN*|MINGW*|MSYS*)
        install_windows
        ;;
    *)
        echo "Hata: Desteklenmeyen isletim sistemi: $OS_TYPE"
        exit 1
        ;;
esac
