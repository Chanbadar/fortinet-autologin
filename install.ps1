<#
.SYNOPSIS
    Fortinet Captive Portal Auto-Login Windows Kurulum Betigi (PowerShell)
#>

[CmdletBinding()]
param ()

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Fortinet Captive Portal Auto-Login Windows Kurulumu     " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallDir = Join-Path -Path $env:APPDATA -ChildPath "fortinet-autologin"
$ScriptTarget = Join-Path -Path $InstallDir -ChildPath "fortinet-autologin.ps1"
$ConfigFile = Join-Path -Path $InstallDir -ChildPath "config.json"
$TaskName = "FortinetAutoLogin"

# 1. Dizin olustur ve calistirilabilir betigi kopyala
if (-not (Test-Path -Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

Copy-Item -Path (Join-Path -Path $ScriptDir -ChildPath "fortinet-autologin.ps1") -Destination $ScriptTarget -Force
Write-Host "[1/3] Betik kopyalandi: $ScriptTarget" -ForegroundColor Green

# 2. Giris Bilgilerini Al ve Guvenli Olarak Sakla (DPAPI ile sifrelenir)
if (-not (Test-Path -Path $ConfigFile)) {
    Write-Host ""
    Write-Host "Lutfen FortiGate portal kullanici bilgilerinizi giriniz:" -ForegroundColor Yellow
    $Username = Read-Host "Kullanici Adi"
    $SecurePass = Read-Host "Sifre" -AsSecureString

    # Windows Data Protection API (DPAPI) ile kullaniciya ozel sifreleme
    $EncryptedPass = $SecurePass | ConvertFrom-SecureString

    $ConfigData = @{
        Username = $Username
        EncryptedPassword = $EncryptedPass
    }

    $ConfigData | ConvertTo-Json | Set-Content -Path $ConfigFile -Encoding UTF8
    Write-Host "Giris bilgileri DPAPI ile sifrelenerek kaydedildi: $ConfigFile" -ForegroundColor Green
} else {
    Write-Host "[2/3] Mevcut yapilandirma dosyasi korundu: $ConfigFile" -ForegroundColor Green
}

# 3. Windows Gorev Zamanlayici (Task Scheduler) Gorevi Olustur
Write-Host "[3/3] Windows Gorev Zamanlayici gorevi yapilandiriliyor..." -ForegroundColor Yellow

$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptTarget`""
$Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1)
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable

# Varsa eski gorevi kaldir
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

# Gorevi kaydet
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description "Fortinet Captive Portal Auto-Login Service" | Out-Null

Write-Host ""
Write-Host "Kurulum basariyla tamamlandi!" -ForegroundColor Cyan
Write-Host "Gorev Zamanlayicisi (Task Scheduler) uzerinde '$TaskName' gorevi her dakika calisacak sekilde kaydedildi."
Write-Host "Log dosyasini takip etmek icin:" -ForegroundColor Gray
Write-Host "  Get-Content -Path `"$InstallDir\fortinet-autologin.log`" -Wait" -ForegroundColor White
Write-Host "Manuel test icin:" -ForegroundColor Gray
Write-Host "  powershell.exe -ExecutionPolicy Bypass -File `"$ScriptTarget`" -DryRun" -ForegroundColor White
