<#
.SYNOPSIS
    FortiGate Captive Portal Otomatik Giris Betigi (Windows PowerShell)
    (https://fortinet.bozok.edu.tr:1003)

.DESCRIPTION
    Her dakika Windows Gorev Zamanlayicisi (Task Scheduler) tarafindan tetiklenir.
    Baglanti aktifse hemen sonlanir. Portal yonlendirmesi tespit edilirse otomatik giris yapar.

.PARAMETER DryRun
    Simulasyon modu. Istek gonderilmez, yalnizca analiz yapilir.
#>

[CmdletBinding()]
param (
    [switch]$DryRun
)

# Guvensiz SSL sertifikalarina izin ver (FortiGate dahili self-signed sertifikalari icin)
try {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Tls12,Tls13'
} catch {}

$ProbeUrl = "http://captive.apple.com/hotspot-detect.html"
$AppDataFolder = Join-Path -Path $env:APPDATA -ChildPath "fortinet-autologin"
$LogFile = Join-Path -Path $AppDataFolder -ChildPath "fortinet-autologin.log"
$ConfigFile = Join-Path -Path $AppDataFolder -ChildPath "config.json"

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp $Message"
    Write-Output $LogEntry
    try {
        if (-not (Test-Path -Path (Split-Path -Path $LogFile -Parent))) {
            New-Item -ItemType Directory -Path (Split-Path -Path $LogFile -Parent) -Force | Out-Null
        }
        Add-Content -Path $LogFile -Value $LogEntry -ErrorAction SilentlyContinue
    } catch {}
}

# 1. Kimlik Bilgilerini Al (Once Ortam Degiskeni, sonra config.json)
$FortinetUser = $env:FORTINET_USER
$FortinetPass = $env:FORTINET_PASS

if ((-not $FortinetUser -or -not $FortinetPass) -and (Test-Path -Path $ConfigFile)) {
    try {
        $Config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
        if (-not $FortinetUser -and $Config.Username) { $FortinetUser = $Config.Username }
        if (-not $FortinetPass -and $Config.EncryptedPassword) {
            $SecurePass = $Config.EncryptedPassword | ConvertTo-SecureString
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePass)
            $FortinetPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        }
    } catch {
        Write-Log "Hata: Yapilandirma dosyasi okunamadi: $_"
    }
}

# 2. Baglanti Testi (Internet erisimi var mi?)
try {
    $Response = Invoke-WebRequest -Uri $ProbeUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    $Content = $Response.Content
    $Headers = $Response.Headers
} catch {
    if ($_.Exception.Response) {
        $Response = $_.Exception.Response
        $Reader = New-Object System.IO.StreamReader($Response.GetResponseStream())
        $Content = $Reader.ReadToEnd()
        $Headers = $Response.Headers
    } else {
        Write-Log "Ag yanit vermiyor (baglanti kopuk veya erisim yok): $($_.Exception.Message)"
        exit 1
    }
}

if ($Content -like "*<TITLE>Success</TITLE>*") {
    if ($DryRun) {
        Write-Log "Internet baglantisi aktif, islem yapilmadi."
    }
    exit 0
}

# 3. FortiGate Auth URL Tespit Etme
$AuthUrl = $null
$RegexPattern = 'https?://[^"'' <>]*:1003/fgtauth\?[0-9A-Za-z]+'

# Once yanit iceriginden ara
if ($Content -match $RegexPattern) {
    $AuthUrl = $Matches[0]
} elseif ($Headers["Location"] -and ($Headers["Location"] -match $RegexPattern)) {
    $AuthUrl = $Matches[0]
}

if (-not $AuthUrl) {
    Write-Log "Cevrimdisi fakat fgtauth yonlendirmesi bulunamadi."
    if ($Content) {
        $Sample = $Content.Substring(0, [Math]::Min(500, $Content.Length))
        Write-Log "Yanit basi: $Sample"
    }
    exit 1
}

Write-Log "Portal algilandi: $AuthUrl"

# 4. Form Detaylarini Oku
try {
    $PageResponse = Invoke-WebRequest -Uri $AuthUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    $Page = $PageResponse.Content
} catch {
    Write-Log "Hata: Portal sayfasi yuklenemedi: $($_.Exception.Message)"
    exit 1
}

function Get-FormFieldValue {
    param([string]$Html, [string]$FieldName)
    $Pattern = 'name="' + $FieldName + '"[^>]*value="([^"]*)"'
    if ($Html -match $Pattern) {
        return $Matches[1]
    }
    return $null
}

$Magic = Get-FormFieldValue -Html $Page -FieldName "magic"
$Redir = Get-FormFieldValue -Html $Page -FieldName "4Tredir"

if (-not $Magic -and ($AuthUrl -match 'fgtauth\?([0-9A-Za-z]+)')) {
    $Magic = $Matches[1]
}

if (-not $Redir) {
    $Redir = $ProbeUrl
}

$BaseUri = [System.Uri]$AuthUrl
$BaseUrl = "$($BaseUri.Scheme)://$($BaseUri.Authority)"

$Body = @{
    "4Tredir" = $Redir
    "magic"   = $Magic
}

$Kind = ""
if ($Page -match 'name="username"') {
    if (-not $FortinetUser -or -not $FortinetPass) {
        Write-Log "HATA: Portal kullanici adi ve sifre istiyor fakat bilgiler tanimli degil!"
        exit 1
    }
    $Body["username"] = $FortinetUser
    $Body["password"] = $FortinetPass
    $Kind = "kimlik bilgileri ile giris"
} else {
    $Body["answer"] = "1"
    $Kind = "disclaimer (sozlesme) onayi"
}

if ($DryRun) {
    Write-Log "Dry-run: $BaseUrl/ adresine POST ($Kind) gonderilecek (magic=$Magic)."
    exit 0
}

# 5. Giris Istegi Gonder ve Dogrula
try {
    $LoginTarget = "$BaseUrl/"
    Invoke-WebRequest -Uri $LoginTarget -Method Post -Body $Body -UseBasicParsing -TimeoutSec 10 -ErrorAction SilentlyContinue | Out-Null
} catch {}

Start-Sleep -Seconds 2

try {
    $CheckResp = Invoke-WebRequest -Uri $ProbeUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    if ($CheckResp.Content -like "*Success*") {
        Write-Log "Giris basarili ($Kind)."
        exit 0
    }
} catch {}

Write-Log "Giris denemesi ($Kind) basarisiz oldu."
exit 1
