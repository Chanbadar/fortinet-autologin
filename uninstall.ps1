<#
.SYNOPSIS
    Fortinet Captive Portal Auto-Login Windows Kaldirma Betigi (PowerShell)
#>

[CmdletBinding()]
param ()

$ErrorActionPreference = "SilentlyContinue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Fortinet Captive Portal Auto-Login Kaldiriliyor...     " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$TaskName = "FortinetAutoLogin"
$InstallDir = Join-Path -Path $env:APPDATA -ChildPath "fortinet-autologin"

# 1. Gorev Zamanlayici gorevini kaldir
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null
Write-Host "[1/2] Gorev Zamanlayici ($TaskName) gorevi kaldirildi." -ForegroundColor Green

# 2. Kurulum dizinini ve dosyalari sil
if (Test-Path -Path $InstallDir) {
    Remove-Item -Path $InstallDir -Recurse -Force | Out-Null
    Write-Host "[2/2] Kurulum dizini ve dosyalar silindi: $InstallDir" -ForegroundColor Green
} else {
    Write-Host "[2/2] Kurulum dizini bulunamadi veya zaten silinmis." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Kaldirma islemi basariyla tamamlandi." -ForegroundColor Cyan
