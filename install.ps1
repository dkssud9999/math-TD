# LIMIT BREAK installer (Windows):  irm https://raw.githubusercontent.com/dkssud9999/math-TD/main/install.ps1 | iex
$ErrorActionPreference = "Stop"
$repo = "dkssud9999/math-TD"
$dest = Join-Path $env:LOCALAPPDATA "LimitBreak"
# Only the game files live in $dest. Progress and algorithms are in %APPDATA%\Godot\app_userdata\Limit Break
# (Godot's user://) and are never touched by installing or updating.
$save = Join-Path $env:APPDATA "Godot\app_userdata\Limit Break"
if (Get-Process -Name "LimitBreak" -ErrorAction SilentlyContinue) {
    Write-Host "LIMIT BREAK이 실행 중입니다. 게임을 닫은 뒤 이 명령을 다시 실행하세요." -ForegroundColor Yellow
    return
}
# Before anything changes: copy the whole save folder (progress + algorithms) to a dated backup.
# If the backup cannot be made, nothing is updated. The newest 5 backups are kept.
if (Test-Path $save) {
    $backups = Join-Path $env:APPDATA "Godot\app_userdata\Limit Break Backups"
    $stamp = Join-Path $backups (Get-Date -Format "yyyyMMdd-HHmmss")
    try {
        New-Item -ItemType Directory -Force $stamp | Out-Null
        Copy-Item (Join-Path $save "*") $stamp -Recurse -Force
    } catch {
        Write-Host "저장 기록을 백업하지 못해 업데이트를 멈췄습니다: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
    Write-Host "저장 기록 백업: $stamp"
    Get-ChildItem $backups -Directory | Sort-Object Name -Descending | Select-Object -Skip 5 |
        ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-Host "LIMIT BREAK: 최신 릴리스를 찾는 중..."
$rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers @{ "User-Agent" = "limitbreak-installer" }
$asset = $rel.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
if (-not $asset) { throw "릴리스에 zip 파일이 없습니다." }
$zip = Join-Path $env:TEMP $asset.name
Write-Host "내려받는 중: $($rel.tag_name) ($([math]::Round($asset.size / 1MB)) MB)"
Invoke-WebRequest $asset.browser_download_url -OutFile $zip -UseBasicParsing
# Unpack next to the install first; the old install is replaced only once the new files are complete,
# so a broken download never leaves the player without a working game.
$new = "$dest.new"
$old = "$dest.old"
foreach ($d in @($new, $old)) { if (Test-Path $d) { Remove-Item $d -Recurse -Force } }
try {
    Expand-Archive $zip -DestinationPath $new -Force
    if (-not ((Test-Path (Join-Path $new "LimitBreak.exe")) -and (Test-Path (Join-Path $new "LimitBreak.pck")))) {
        throw "내려받은 파일에 LimitBreak.exe / LimitBreak.pck가 없습니다."
    }
} catch {
    if (Test-Path $new) { Remove-Item $new -Recurse -Force -ErrorAction SilentlyContinue }
    Remove-Item $zip -ErrorAction SilentlyContinue
    Write-Host "업데이트 실패: $($_.Exception.Message) 기존 설치는 그대로입니다. 다시 실행해 보세요." -ForegroundColor Red
    return
}
Remove-Item $zip -ErrorAction SilentlyContinue
if (Test-Path $dest) { Rename-Item $dest (Split-Path $old -Leaf) }
try {
    Rename-Item $new (Split-Path $dest -Leaf)
} catch {
    if (Test-Path $old) { Rename-Item $old (Split-Path $dest -Leaf) }
    Write-Host "업데이트 실패: 설치 폴더를 바꾸지 못했습니다. 기존 설치는 그대로입니다." -ForegroundColor Red
    return
}
if (Test-Path $old) { Remove-Item $old -Recurse -Force -ErrorAction SilentlyContinue }
$lnk = Join-Path ([Environment]::GetFolderPath("Desktop")) "LIMIT BREAK.lnk"
$sh = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
$sh.TargetPath = Join-Path $dest "LimitBreak.exe"
$sh.WorkingDirectory = $dest
$ico = Join-Path $dest "icon.ico"
if (Test-Path $ico) { $sh.IconLocation = $ico }
$sh.Save()
Write-Host "설치 완료: $dest"
if (Test-Path (Join-Path $save "limit_break_save.json")) {
    Write-Host "기존 저장 기록을 그대로 이어서 씁니다: $save"
}
Write-Host "바탕화면의 'LIMIT BREAK' 바로가기로 실행하세요."
