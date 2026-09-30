# Runs the dev build on a USB phone (or the emulator). The dev build calls the
# API on this computer at http://127.0.0.1:4000, which the phone reaches only
# through `adb reverse`, lost on every reconnect. Forgetting it once left a
# phone silently offline for a day, so this does it every time.
#
#   .\tool\run_dev.ps1              # then any extra `flutter run` args, e.g. -d <id>
#
# Several devices attached: set $env:ANDROID_SERIAL to pick one for adb.

$adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
if (-not $adb) {
    # Not on PATH: Android Studio's default SDK folder (where it is on the dev PC).
    $adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
}
if (-not (Test-Path $adb)) {
    throw "adb not found on PATH or at $adb. Add the Android SDK platform-tools folder to PATH."
}
& $adb reverse tcp:4000 tcp:4000
if ($LASTEXITCODE -ne 0) {
    throw 'adb reverse failed: is a phone connected with USB debugging allowed? Check with: adb devices'
}

Push-Location (Split-Path $PSScriptRoot)
try {
    flutter run --flavor owest @args
} finally {
    Pop-Location
}
exit $LASTEXITCODE
