# Fortinet Captive Portal Auto-Login

A lightweight, automated captive portal login utility designed for FortiGate authentication environments (such as Bozok University and similar academic/enterprise networks). Compatible with **Linux**, **macOS**, and **Windows**.

---

## Türkçe Dokümantasyon

### Genel Bakış

Bu araç, FortiGate Captive Portal (Web Kimlik Doğrulama) kullanan ağlarda oturumun zaman aşımına uğraması veya ağ bağlantısının kesilmesi durumunda otomatik olarak sisteme yeniden giriş yapar.

Arka planda sürekli bellek tüketen bir servis çalıştırmak yerine, işletim sisteminin yerel zamanlayıcı mekanizmalarını (Linux'ta `systemd timer`, macOS'ta `launchd`, Windows'ta `Task Scheduler / Görev Zamanlayıcı`) kullanır. Her dakika hafif bir ağ kontrolü yapar; internet erişimi mevcutsa anında sonlanır ve hiçbir bellek ya da işlemci yükü oluşturmaz. Bağlantı kesilmişse portala otomatik POST isteği göndererek oturumu yeniden açar.

### Temel Özellikler

- **Çapraz Platform Desteği:** Linux, macOS ve Windows üzerinde yerel servis / zamanlayıcı mimarisiyle çalışır.
- **Sıfır Bellek Tüketimi:** Arka planda kalıcı süreç tutmaz; yalnızca kontrol anında tetiklenir ve işi bitince kapanır.
- **Güvenli Kimlik Yönetimi:**
  - **Linux:** Yalnızca `root` kullanıcısının okuyabileceği (`chmod 600`) yapılandırma dosyası (`/etc/fortinet-autologin/config.env`) kullanır.
  - **macOS:** Şifreleri doğrudan işletim sisteminin şifreli Anahtar Zinciri'nde (`Keychain`) saklar.
  - **Windows:** Şifreleri Windows Veri Koruma API'si (`DPAPI / ConvertFrom-SecureString`) ile geçerli kullanıcı oturumuna özel şifreler (`%APPDATA%\fortinet-autologin\config.json`).
- **Akıllı Algılama:** FortiGate yönlendirmesindeki dinamik oturum belirtecini (`magic` parametresi) ve yönlendirme adreslerini otomatik ayrıştırır.

### Desteklenen Platformlar ve Gereksinimler

- **Linux:** `systemd` kullanan tüm dağıtımlar (Arch Linux, Ubuntu, Debian, Fedora, CentOS vb.), `bash`, `curl`.
- **macOS:** OS X / macOS 10.10 ve üzeri sürümler, `launchd`, `security`, `curl`.
- **Windows:** Windows 7 / 8 / 10 / 11 veya Windows Server, PowerShell 5.1+ (Windows Görev Zamanlayıcısı).

### Kurulum

Depoyu sisteminize klonlayın:

```bash
git clone https://github.com/Chanbadar/fortinet-autologin.git
cd fortinet-autologin
```

#### Linux Kurulumu:
Linux üzerinde kurulum systemd servislerini yapılandırdığı için yönetici yetkisi gerektirir:
```bash
chmod +x install.sh uninstall.sh
sudo ./install.sh
```
Kurulum sırasında portal kullanıcı adı ve şifreniz istenecektir. Bilgiler `/etc/fortinet-autologin/config.env` dosyasına güvenli erişim izinleriyle kaydedilecektir.

#### macOS Kurulumu:
macOS üzerinde root yetkisi gerekmez, doğrudan kullanıcı seviyesinde çalıştırılır:
```bash
chmod +x install.sh uninstall.sh
./install.sh
```
Kurulum sırasında istenen kimlik bilgileri sisteminizin yerel Keychain deposuna eklenecektir.

#### Windows Kurulumu:
Windows üzerinde PowerShell açarak kurulum betiğini çalıştırın (veya Git Bash kullanıyorsanız `./install.sh` çalıştırabilirsiniz):

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```
Kurulum sırasında portal kullanıcı adı ve şifreniz istenir ve Windows DPAPI ile şifrelenerek kaydedilir. Ardından her dakika çalışacak bir Windows Görev Zamanlayıcısı (`FortinetAutoLogin`) oluşturulur.

### Manuel Test ve Betik Parametreleri

Sistemi arka plan servisi kurmadan doğrudan terminalden test edebilirsiniz:

- **Simülasyon Modu (`--dry-run` / `-DryRun`):**
  Ağ durumunu kontrol eder, FortiGate portalını ve oturum parametrelerini algılar; ancak sisteme giriş isteği göndermeden durur.
  ```bash
  # Linux için:
  ./fortinet-autologin-linux.sh --dry-run

  # macOS için:
  ./fortinet-autologin.sh --dry-run

  # Windows (PowerShell) için:
  powershell -ExecutionPolicy Bypass -File fortinet-autologin.ps1 -DryRun
  ```

- **Ortam Değişkeni ile Çalıştırma:**
  ```bash
  # Linux / macOS:
  FORTINET_USER="kullanici_adi" FORTINET_PASS="sifre" ./fortinet-autologin-linux.sh

  # Windows (PowerShell):
  $env:FORTINET_USER="kullanici_adi"; $env:FORTINET_PASS="sifre"; powershell -ExecutionPolicy Bypass -File fortinet-autologin.ps1
  ```

### Yönetim ve Log İnceleme

#### Linux (systemd):
- Zamanlayıcı durumunu kontrol etme:
  ```bash
  systemctl status fortinet-autologin.timer
  ```
- Canlı servis loglarını izleme:
  ```bash
  journalctl -u fortinet-autologin.service -f
  ```
- Log dosyasını okuma:
  ```bash
  cat /var/log/fortinet-autologin.log
  ```

#### macOS (launchd):
- Servis durumunu listeleme:
  ```bash
  launchctl list | grep fortinet-autologin
  ```
- Log dosyasını izleme:
  ```bash
  tail -f ~/Library/Logs/fortinet-autologin.log
  ```

#### Windows (Görev Zamanlayıcı):
- Görev durumunu kontrol etme:
  ```powershell
  Get-ScheduledTask -TaskName FortinetAutoLogin
  ```
- Log dosyasını izleme:
  ```powershell
  Get-Content -Path "$env:APPDATA\fortinet-autologin\fortinet-autologin.log" -Wait -Tail 20
  ```

### Kaldırma

Aracı sistemden tüm servisleri, zamanlayıcıları ve yapılandırma dosyalarıyla birlikte kaldırmak için:

```bash
# Linux:
sudo ./uninstall.sh

# macOS:
./uninstall.sh

# Windows (PowerShell):
powershell -ExecutionPolicy Bypass -File uninstall.ps1
# (veya Git Bash kullanıyorsanız: ./uninstall.sh)
```

---

## English Documentation

### Overview

This utility automates the re-authentication process for FortiGate Captive Portal environments whenever a session expires or network connectivity drops.

Rather than running a continuous background daemon that consumes memory, it leverages the operating system's native scheduling framework (`systemd timer` on Linux, `launchd` on macOS, `Task Scheduler` on Windows). It performs a lightweight connectivity probe once every minute; if access is active, it exits immediately with zero residual memory footprint. If redirected to the captive portal, it extracts authentication tokens and executes the login request automatically.

### Key Features

- **Cross-Platform:** Native system integration on Linux, macOS, and Windows.
- **Resource Efficient:** Ephemeral execution model ensures no background processes remain resident in memory.
- **Secure Credential Storage:**
  - **Linux:** Credentials are saved under `/etc/fortinet-autologin/config.env` with restricted permissions (`chmod 600`).
  - **macOS:** Credentials are encrypted and stored via the native macOS Keychain system.
  - **Windows:** Credentials are encrypted using the Windows Data Protection API (DPAPI) and stored in `%APPDATA%\fortinet-autologin\config.json`.
- **Dynamic Token Extraction:** Automatically parses portal redirect URLs, magic strings, and CSRF parameters.

### Prerequisites

- **Linux:** Any modern Linux distribution utilizing `systemd`, `bash`, `curl`.
- **macOS:** OS X / macOS 10.10+, `launchd`, `security`, `curl`.
- **Windows:** Windows 7/8/10/11 or Windows Server, PowerShell 5.1+ (Windows Task Scheduler).

### Installation

Clone the repository:

```bash
git clone https://github.com/Chanbadar/fortinet-autologin.git
cd fortinet-autologin
```

#### Linux Installation:
Requires administrative privileges to configure systemd units:
```bash
chmod +x install.sh uninstall.sh
sudo ./install.sh
```
The installer prompts for portal credentials and stores them securely.

#### macOS Installation:
Runs under user space without needing root privileges:
```bash
chmod +x install.sh uninstall.sh
./install.sh
```
The installer prompts for credentials and writes them to the macOS Keychain.

#### Windows Installation:
Open PowerShell and execute `install.ps1` (or run `./install.sh` from Git Bash):

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```
The installer prompts for credentials, encrypts them securely using DPAPI, and registers a Task Scheduler entry (`FortinetAutoLogin`) that runs every minute.

### Manual Execution and Script Flags

The scripts can be invoked manually for diagnostic purposes:

- **Simulation Mode (`--dry-run` / `-DryRun`):**
  Performs probe requests and detects the FortiGate authentication endpoint without posting credentials.
  ```bash
  # Linux:
  ./fortinet-autologin-linux.sh --dry-run

  # macOS:
  ./fortinet-autologin.sh --dry-run

  # Windows (PowerShell):
  powershell -ExecutionPolicy Bypass -File fortinet-autologin.ps1 -DryRun
  ```

- **Execution via Environment Variables:**
  ```bash
  # Linux / macOS:
  FORTINET_USER="username" FORTINET_PASS="password" ./fortinet-autologin-linux.sh

  # Windows (PowerShell):
  $env:FORTINET_USER="username"; $env:FORTINET_PASS="password"; powershell -ExecutionPolicy Bypass -File fortinet-autologin.ps1
  ```

### Service Management and Logs

#### Linux (systemd):
- Check timer status:
  ```bash
  systemctl status fortinet-autologin.timer
  ```
- Tail journal logs:
  ```bash
  journalctl -u fortinet-autologin.service -f
  ```
- View flat file log:
  ```bash
  cat /var/log/fortinet-autologin.log
  ```

#### macOS (launchd):
- Inspect loaded job:
  ```bash
  launchctl list | grep fortinet-autologin
  ```
- Stream logs:
  ```bash
  tail -f ~/Library/Logs/fortinet-autologin.log
  ```

#### Windows (Task Scheduler):
- Inspect scheduled task:
  ```powershell
  Get-ScheduledTask -TaskName FortinetAutoLogin
  ```
- Stream logs:
  ```powershell
  Get-Content -Path "$env:APPDATA\fortinet-autologin\fortinet-autologin.log" -Wait -Tail 20
  ```

### Uninstallation

To remove all installed services, timers, and configuration files:

```bash
# Linux:
sudo ./uninstall.sh

# macOS:
./uninstall.sh

# Windows (PowerShell):
powershell -ExecutionPolicy Bypass -File uninstall.ps1
# (or from Git Bash: ./uninstall.sh)
```
