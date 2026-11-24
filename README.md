# Fortinet Captive Portal Auto-Login (Linux)

Bozok Universitesi ve benzeri FortiGate Captive Portal (Web Authentication) aglarinda baglantiyi surekli acik tutan ve kesildiginde otomatik olarak yeniden giris yapan otomasyon aracidir.

Orijinal macOS betigi korunmus, Linux platformu icin bagimsiz ve tum dagitimlarda calisacak sekilde optimize edilmistir.

## Calisma Mantigi

1. Sistem arka planinda (systemd timer) her dakika kontrol gerceklestirilir.
2. `http://captive.apple.com/hotspot-detect.html` adresine hafif bir HTTP sorgusu atilir.
3. Eger internet baglantisi zaten aktifse betik herhangi bir islem yapmadan aninda sonlanir (RAM ve islemci tuketimi 0 olur).
4. Eger ag tarafindan kesilme (timeout) olmussa veya giris sayfasi tespit edilmisse:
   - Portal yonlendirme adresi ve oturum kodu (magic key) otomatik ayiklanir.
   - Tanımlanan kullanici bilgileri ile HTTPS POST istegi yapilarak oturum acilir.
   - Giris yapildigi teyit edilir ve log kaydi olusturulur.

## Gereksinimler

- Herhangi bir Linux dagitimi (Arch Linux, Ubuntu, Debian, Fedora, CentOS vb.)
- `bash` kabugu
- `curl` araci
- `systemd` (otomatik zamanlayici servisi icin)

## Kurulum

1. Depoyu klonlayin veya dosyalari indirin:
```bash
git clone <repo-url>
cd fortinet-autologin
```

2. Kurulum betigini calistirin:
```bash
chmod +x install.sh
sudo ./install.sh
```

Kurulum sirasinda sizden kullanici adi ve sifreniz istenecektir. Bu bilgiler yalnizca root kullanicisinin okuyabilecegi `/etc/fortinet-autologin/config.env` dosyasina kaydedilir (izin: 600).

Kurulum tamamlandiginda `systemd timer` otomatik olarak baslatilir ve her dakika calisacak sekilde ayarlanir.

## Manuel Calistirma ve Test

Servis kurulmadan da betik dogrudan test edilebilir:

Test modunda calistirmak icin:
```bash
chmod +x fortinet-autologin-linux.sh
./fortinet-autologin-linux.sh --dry-run
```

Ortam degiskeni belirterek calistirmak icin:
```bash
FORTINET_USER="kullanici_adi" FORTINET_PASS="sifre" ./fortinet-autologin-linux.sh
```

## Yonetim Komutlari

Zamanlayicinin durumunu kontrol etme:
```bash
systemctl status fortinet-autologin.timer
```

Servisin calisma gecmisini ve loglarini izleme:
```bash
journalctl -u fortinet-autologin.service -f
```

veya dosya logunu inceleme:
```bash
cat /var/log/fortinet-autologin.log
```

Zamanlayiciyi gecici olarak durdurma:
```bash
sudo systemctl stop fortinet-autologin.timer
```

Zamanlayiciyi yeniden baslatma:
```bash
sudo systemctl start fortinet-autologin.timer
```

## Kaldirma

Sistemdeki tum servisleri, zamanlayicilari ve yapilandirma dosyalarini tamamen temizlemek icin:
```bash
chmod +x uninstall.sh
sudo ./uninstall.sh
```
