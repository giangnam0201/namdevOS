# namdevOS ISO Boot Fixer for Windows
# Extracts ISO with 7-Zip, fixes boot config, repacks with oscdimg or cdrtools.
#
# Usage: powershell -ExecutionPolicy Bypass -File fix-iso.ps1 -IsoPath "path\to\iso"

param(
    [Parameter(Mandatory=$true)]
    [string]$IsoPath
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $IsoPath)) {
    Write-Host "ERROR: ISO not found: $IsoPath" -ForegroundColor Red
    exit 1
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  namdevOS ISO Boot Fixer" -ForegroundColor Cyan  
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Find 7-Zip
$sevenZip = $null
foreach ($p in @("C:\Program Files\7-Zip\7z.exe", "C:\Program Files (x86)\7-Zip\7z.exe")) {
    if (Test-Path $p) { $sevenZip = $p; break }
}
if (-not $sevenZip) {
    try { $sevenZip = (Get-Command 7z -ErrorAction Stop).Source } catch {}
}
if (-not $sevenZip) {
    Write-Host "ERROR: 7-Zip not found. Install from https://7-zip.org" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] 7-Zip: $sevenZip" -ForegroundColor Green

# Create work directory next to the ISO
$isoDir = Split-Path $IsoPath -Parent
$isoName = [System.IO.Path]::GetFileNameWithoutExtension($IsoPath)
$workDir = Join-Path $isoDir "${isoName}-work"
$extractDir = Join-Path $workDir "iso"

if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force }
New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

# Extract
Write-Host "[INFO] Extracting ISO (this takes a minute)..." -ForegroundColor Blue
$proc = Start-Process -FilePath $sevenZip -ArgumentList "x `"$IsoPath`" -o`"$extractDir`" -y" -Wait -PassThru -NoNewWindow
if ($proc.ExitCode -ne 0) {
    Write-Host "ERROR: Extraction failed" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Extracted" -ForegroundColor Green

# Find kernel and initrd
Write-Host "[INFO] Locating kernel..." -ForegroundColor Blue
$kernelPath = $null
$initrdPath = $null

foreach ($dir in @("casper", "live", "boot")) {
    $fullDir = Join-Path $extractDir $dir
    if (Test-Path $fullDir) {
        $k = Get-ChildItem $fullDir -Filter "vmlinuz*" -ErrorAction SilentlyContinue | Select-Object -First 1
        $i = Get-ChildItem $fullDir -Filter "initrd*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($k) { $kernelPath = "/$dir/$($k.Name)" }
        if ($i) { $initrdPath = "/$dir/$($i.Name)" }
        if ($kernelPath -and $initrdPath) { break }
    }
}

if (-not $kernelPath) {
    Write-Host "ERROR: vmlinuz not found in ISO" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Kernel: $kernelPath" -ForegroundColor Green
Write-Host "[OK] Initrd: $initrdPath" -ForegroundColor Green

# Write fixed isolinux.cfg
$isolinuxDir = Join-Path $extractDir "isolinux"
if (-not (Test-Path $isolinuxDir)) { New-Item -ItemType Directory -Path $isolinuxDir -Force | Out-Null }

$cfg = @"
DEFAULT live
TIMEOUT 50
PROMPT 0

UI menu.c32

MENU TITLE namdevOS Boot Menu
MENU COLOR title  1;36;40 #ff00d2d3 #00000000 none
MENU COLOR sel    7;37;40 #ffe94560 #00000000 none
MENU COLOR unsel  37;40   #ffe0e0e0 #00000000 none
MENU COLOR border 37;40   #00000000 #00000000 none

LABEL live
    MENU LABEL ^Start namdevOS
    MENU DEFAULT
    KERNEL $kernelPath
    APPEND initrd=$initrdPath boot=casper quiet splash ---

LABEL live-safe
    MENU LABEL Start namdevOS (Safe Mode)
    KERNEL $kernelPath
    APPEND initrd=$initrdPath boot=casper xforcevesa nomodeset quiet splash ---
"@
Set-Content (Join-Path $isolinuxDir "isolinux.cfg") -Value $cfg -Encoding ASCII
Write-Host "[OK] isolinux.cfg written" -ForegroundColor Green

# Also fix GRUB (for UEFI boot)
$grubCfg = Join-Path $extractDir "boot\grub\grub.cfg"
if (Test-Path $grubCfg) {
    $grubContent = Get-Content $grubCfg -Raw
    # Replace any wrong vmlinuz/initrd references
    $grubContent = $grubContent -replace '/casper/vmlinuz\b', $kernelPath
    $grubContent = $grubContent -replace '/casper/initrd\b', $initrdPath
    $grubContent = $grubContent -replace '/live/vmlinuz\b', $kernelPath
    $grubContent = $grubContent -replace '/live/initrd\b', $initrdPath
    Set-Content $grubCfg -Value $grubContent -Encoding UTF8
    Write-Host "[OK] grub.cfg paths updated" -ForegroundColor Green
}

# Also check loopback.cfg
$loopCfg = Join-Path $extractDir "boot\grub\loopback.cfg"  
if (Test-Path $loopCfg) {
    $loopContent = Get-Content $loopCfg -Raw
    $loopContent = $loopContent -replace '/casper/vmlinuz\b', $kernelPath
    $loopContent = $loopContent -replace '/casper/initrd\b', $initrdPath
    Set-Content $loopCfg -Value $loopContent -Encoding UTF8
    Write-Host "[OK] loopback.cfg updated" -ForegroundColor Green
}

# Repack ISO
$outputIso = Join-Path $isoDir "${isoName}-fixed.iso"
Write-Host ""
Write-Host "[INFO] Repacking ISO..." -ForegroundColor Blue

# Method 1: Try oscdimg (Windows ADK)
$oscdimg = $null
$adkPaths = @(
    "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
    "${env:ProgramFiles}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
)
foreach ($p in $adkPaths) { if (Test-Path $p) { $oscdimg = $p; break } }

# Method 2: Try mkisofs/genisoimage
$mkisofs = $null
foreach ($p in @("mkisofs", "genisoimage")) {
    try { $mkisofs = (Get-Command $p -ErrorAction Stop).Source; break } catch {}
}

if ($oscdimg) {
    Write-Host "[INFO] Using oscdimg (Windows ADK)..." -ForegroundColor Blue
    $etfsboot = Join-Path $isolinuxDir "isolinux.bin"
    & $oscdimg -l -d -N -b"$etfsboot" -h -o "$extractDir" "$outputIso"
} elseif ($mkisofs) {
    Write-Host "[INFO] Using mkisofs..." -ForegroundColor Blue
    & $mkisofs -o "$outputIso" -b "isolinux/isolinux.bin" -c "isolinux/boot.cat" -no-emul-boot -boot-load-size 4 -boot-info-table -J -R -V "namdevOS" "$extractDir"
} else {
    # Method 3: Download portable mkisofs
    Write-Host "[INFO] Downloading portable cdrtools (mkisofs)..." -ForegroundColor Blue
    $mkisofsUrl = "https://github.com/AdrianBan/cdrtools-win/releases/download/cdrtools-3.02a09/cdrtools-3.02a09-win32-bin.zip"
    $zipPath = Join-Path $workDir "cdrtools.zip"
    $cdrtoolsDir = Join-Path $workDir "cdrtools"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $mkisofsUrl -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $cdrtoolsDir -Force
        
        # Find mkisofs.exe in extracted files
        $mkisofsExe = Get-ChildItem $cdrtoolsDir -Recurse -Filter "mkisofs.exe" | Select-Object -First 1
        
        if ($mkisofsExe) {
            Write-Host "[OK] mkisofs downloaded" -ForegroundColor Green
            $mkisofsPath = $mkisofsExe.FullName
            
            & $mkisofsPath -o "$outputIso" `
                -b "isolinux/isolinux.bin" `
                -c "isolinux/boot.cat" `
                -no-emul-boot `
                -boot-load-size 4 `
                -boot-info-table `
                -J -R `
                -V "namdevOS" `
                "$extractDir"
        } else {
            throw "mkisofs.exe not found in download"
        }
    } catch {
        Write-Host ""
        Write-Host "[WARN] Could not download mkisofs. Error: $_" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "  MANUAL FIX INSTRUCTIONS" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "The boot configs have been fixed in:" -ForegroundColor White
        Write-Host "  $extractDir" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "To create a bootable ISO, do ONE of these:" -ForegroundColor White
        Write-Host ""
        Write-Host "Option A - Use Rufus directly:" -ForegroundColor Green
        Write-Host "  1. Download Rufus: https://rufus.ie" -ForegroundColor White
        Write-Host "  2. Select your USB drive" -ForegroundColor White
        Write-Host "  3. Select the ORIGINAL ISO: $IsoPath" -ForegroundColor White  
        Write-Host "  4. Rufus will boot it fine (it uses GRUB which already works)" -ForegroundColor White
        Write-Host ""
        Write-Host "Option B - Boot in VirtualBox/VMware:" -ForegroundColor Green
        Write-Host "  Just use the original ISO - VMs use GRUB/EFI which works." -ForegroundColor White
        Write-Host "  The isolinux issue only affects legacy BIOS USB boot." -ForegroundColor White
        Write-Host ""
        Write-Host "Option C - Install Windows ADK for oscdimg:" -ForegroundColor Green
        Write-Host "  https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install" -ForegroundColor White
        Write-Host "  Then rerun this script." -ForegroundColor White
        Write-Host ""
        
        # Cleanup
        Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
        exit 0
    }
}

# Check result
if (Test-Path $outputIso) {
    $size = [math]::Round((Get-Item $outputIso).Length / 1GB, 2)
    
    # Cleanup work directory
    Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "  DONE!" -ForegroundColor Green
    Write-Host "  Fixed ISO: $outputIso" -ForegroundColor Green
    Write-Host "  Size: ${size} GB" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Write to USB with Rufus or test in a VM." -ForegroundColor Cyan
} else {
    Write-Host "ERROR: Repacking failed" -ForegroundColor Red
    Write-Host "Extracted files remain at: $extractDir" -ForegroundColor Yellow
    exit 1
}
