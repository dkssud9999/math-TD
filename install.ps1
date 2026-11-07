# LIMIT BREAK installer (Windows):  irm https://raw.githubusercontent.com/dkssud9999/math-TD/main/install.ps1 | iex
$ErrorActionPreference = "Stop"
$repo = "dkssud9999/math-TD"
$dest = Join-Path $env:LOCALAPPDATA "LimitBreak"
Write-Host "LIMIT BREAK: 최신 릴리스를 찾는 중..."
$rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers @{ "User-Agent" = "limitbreak-installer" }
$asset = $rel.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
if (-not $asset) { throw "릴리스에 zip 파일이 없습니다." }
$zip = Join-Path $env:TEMP $asset.name
Write-Host "내려받는 중: $($rel.tag_name) ($([math]::Round($asset.size / 1MB)) MB)"
Invoke-WebRequest $asset.browser_download_url -OutFile $zip -UseBasicParsing
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
Expand-Archive $zip -DestinationPath $dest -Force
Remove-Item $zip
$lnk = Join-Path ([Environment]::GetFolderPath("Desktop")) "LIMIT BREAK.lnk"
$sh = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
$sh.TargetPath = Join-Path $dest "LimitBreak.exe"
$sh.WorkingDirectory = $dest
$sh.Save()
Write-Host "설치 완료: $dest"
Write-Host "바탕화면의 'LIMIT BREAK' 바로가기로 실행하세요. (저장 기록은 %APPDATA%\Godot\app_userdata\Limit Break)"
