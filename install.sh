#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="/usr/local/bin/fortinet-autologin"
CONF_DIR="/etc/fortinet-autologin"
CONF_FILE="$CONF_DIR/config.env"
SYSTEMD_DIR="/etc/systemd/system"

echo "Fortinet Autologin kurulumu baslatiliyor..."

if [ "$EUID" -ne 0 ]; then
    echo "Hata: Bu script root yetkisi ile calistirilmalidir."
    echo "Kullanim: sudo ./install.sh"
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "Hata: 'curl' komutu bulunamadi. Lutfen once curl paketini kurun."
    exit 1
fi

echo "[1/4] Calistirilabilir dosya kopyalaniyor: $BIN_PATH"
cp "$SCRIPT_DIR/fortinet-autologin-linux.sh" "$BIN_PATH"
chmod 755 "$BIN_PATH"

echo "[2/4] Yapilandirma dosyasi kontrol ediliyor..."
mkdir -p "$CONF_DIR"
chmod 700 "$CONF_DIR"

if [ ! -f "$CONF_FILE" ]; then
    echo "Lutfen portal giris bilgilerinizi giriniz:"
    read -rp "Kullanici Adi: " input_user
    read -rsp "Sifre: " input_pass
    echo ""

    cat <<EOF > "$CONF_FILE"
# FortiGate Giris Bilgileri
FORTINET_USER="$input_user"
FORTINET_PASS="$input_pass"
EOF
    chmod 600 "$CONF_FILE"
    echo "Giris bilgileri $CONF_FILE dosyasina kaydedildi."
else
    echo "Mevcut yapilandirma dosyasi korundu: $CONF_FILE"
fi

echo "[3/4] Systemd servis ve zamanlayici (timer) dosyalari olusturuluyor..."

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

echo "[4/4] Servisler etkinlestiriliyor ve baslatiliyor..."
systemctl daemon-reload
systemctl enable --now fortinet-autologin.timer

echo "Kurulum tamamlandi."
echo "Zamanlayici aktif: her dakika ag kontrol edilecek, gerekiyorsa giris yapilacaktir."
echo "Durumu kontrol etmek icin: systemctl status fortinet-autologin.timer"
echo "Loglari gormek icin: journalctl -u fortinet-autologin.service -f"
