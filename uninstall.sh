#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
    echo "Hata: Bu script root yetkisi ile calistirilmalidir."
    echo "Kullanim: sudo ./uninstall.sh"
    exit 1
fi

echo "Fortinet Autologin servisi kaldiriliyor..."

systemctl stop fortinet-autologin.timer 2>/dev/null || true
systemctl disable fortinet-autologin.timer 2>/dev/null || true

rm -f /etc/systemd/system/fortinet-autologin.service
rm -f /etc/systemd/system/fortinet-autologin.timer
systemctl daemon-reload

rm -f /usr/local/bin/fortinet-autologin
rm -rf /etc/fortinet-autologin

echo "Tum bilesenler ve servisler basariyla kaldirildi."
