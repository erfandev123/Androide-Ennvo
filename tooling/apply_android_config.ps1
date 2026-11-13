# ============================================================================
#  Applies the Android project customisations after `flutter create`:
#
#    • the application id stays `com.erfan.ennvoapp` so the app keeps the
#      existing Firebase registration, the Play Store listing and the push
#      tokens
#    • the Google Services configuration is copied in
#    • the native shell with the device-tier channel replaces the template
#    • Gradle is tuned for a small machine
# ============================================================================

param(
    [string]$ProjectRoot = "C:\Users\erfan\3D Objects\Ennvo native androide",
    [string]$EnnvoWebApp = "C:\Users\erfan\3D Objects\Ennvo"
)

$ErrorActionPreference = "Stop"

$app = Join-Path $ProjectRoot "android\app"
if (-not (Test-Path $app)) { throw "android/app not found — run flutter create first." }

Write-Host "==> application id"
$gradleKts = Join-Path $app "build.gradle.kts"
$gradleGroovy = Join-Path $app "build.gradle"
foreach ($file in @($gradleKts, $gradleGroovy)) {
    if (Test-Path $file) {
        $content = Get-Content $file -Raw
        $content = $content -replace 'applicationId\s*=\s*"[^"]*"', 'applicationId = "com.erfan.ennvoapp"'
        $content = $content -replace 'namespace\s*=\s*"[^"]*"', 'namespace = "com.erfan.ennvoapp"'
        Set-Content -Path $file -Value $content -NoNewline
        Write-Host "    patched $(Split-Path $file -Leaf)"
    }
}

Write-Host "==> google services"
Copy-Item (Join-Path $EnnvoWebApp "android\app\google-services.json") (Join-Path $app "google-services.json") -Force

# The Google Services Gradle plugin has to be applied for the file above to
# be read.
$settings = Join-Path $ProjectRoot "android\settings.gradle.kts"
if (Test-Path $settings) {
    $content = Get-Content $settings -Raw
    if ($content -notmatch 'com\.google\.gms\.google-services') {
        $content = $content -replace 'plugins\s*\{', @"
plugins {
    id("com.google.gms.google-services") version "4.4.2" apply false
"@
        Set-Content -Path $settings -Value $content -NoNewline
        Write-Host "    added the google-services plugin"
    }
}

Write-Host "==> native shell"
$kotlinDir = Join-Path $app "src\main\kotlin\com\erfan\ennvoapp"
New-Item -ItemType Directory -Force -Path $kotlinDir | Out-Null
Copy-Item (Join-Path $ProjectRoot "tooling\MainActivity.kt") (Join-Path $kotlinDir "MainActivity.kt") -Force

# The template's MainActivity lives under a different package path.
$oldKotlinDir = Join-Path $app "src\main\kotlin\com\erfan\ennvo"
if (Test-Path $oldKotlinDir) { Remove-Item $oldKotlinDir -Recurse -Force }

Write-Host "==> gradle tuning"
$props = Join-Path $ProjectRoot "android\gradle.properties"
$content = Get-Content $props -Raw
$tuning = @"

# --- Ennvo: tuned for small build machines -------------------------------
org.gradle.jvmargs=-Xmx1536M -XX:MaxMetaspaceSize=512M -Dfile.encoding=UTF-8
org.gradle.workers.max=1
org.gradle.parallel=false
org.gradle.caching=true
org.gradle.configureondemand=true
kotlin.compiler.execution.strategy=in-process
kotlin.daemon.jvmargs=-Xmx768M
android.useAndroidX=true
android.enableJetifier=false
android.nonTransitiveRClass=true
"@
if ($content -notmatch 'Ennvo: tuned for small build machines') {
    Set-Content -Path $props -Value ($content + $tuning) -NoNewline
    Write-Host "    gradle.properties tuned"
}

Write-Host "==> manifest"
$manifest = Join-Path $app "src\main\AndroidManifest.xml"
$content = Get-Content $manifest -Raw
if ($content -notmatch 'android:usesCleartextTraffic') {
    $content = $content -replace '<application', @"
<application
        android:usesCleartextTraffic="true"
"@
    Set-Content -Path $manifest -Value $content -NoNewline
    Write-Host "    cleartext traffic enabled for local development"
}

Write-Host "==> done"
