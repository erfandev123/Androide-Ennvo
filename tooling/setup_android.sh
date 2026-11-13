#!/usr/bin/env bash
# ============================================================================
#  Sets up the Android project of the Ennvo app.
#
#  The repository keeps the Dart sources only, so the platform folders are
#  generated here. That keeps the repository small and means the Android
#  project always matches the Flutter SDK that builds it.
#
#  The script is idempotent: when `android/` already exists it only applies
#  the Ennvo specific customisations.
# ============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."

APPLICATION_ID="com.erfan.ennvoapp"

echo "==> Flutter SDK: $(flutter --version | head -1)"

# ---------------------------------------------------------------------------
#  Generate the platform folders when they are missing.
# ---------------------------------------------------------------------------
if [ ! -d android ]; then
    echo "==> Generating the Android project"
    flutter create --platforms=android,ios --project-name ennvo --org com.erfan --no-pub .
    # `flutter create` may refresh the template files; keep our sources.
    git checkout -- lib pubspec.yaml analysis_options.yaml 2>/dev/null || true
    # The template widget test references a `MyApp` class this project does
    # not have.
    rm -f test/widget_test.dart
fi

mkdir -p "android/app/src/main/kotlin/com/erfan/ennvoapp"

# ---------------------------------------------------------------------------
#  The native shell with the device-tier channel.
# ---------------------------------------------------------------------------
echo "==> Installing the native shell"
cp tooling/MainActivity.kt "android/app/src/main/kotlin/com/erfan/ennvoapp/MainActivity.kt"
rm -rf "android/app/src/main/kotlin/com/erfan/ennvo"

# ---------------------------------------------------------------------------
#  The application id — it has to stay `com.erfan.ennvoapp` so the app keeps
#  the existing Firebase registration and the push tokens.
# ---------------------------------------------------------------------------
echo "==> Setting the application id to $APPLICATION_ID"
for file in android/app/build.gradle.kts android/app/build.gradle; do
    [ -f "$file" ] || continue
    sed -i "s/applicationId = \".*\"/applicationId = \"$APPLICATION_ID\"/" "$file"
    sed -i "s/namespace = \".*\"/namespace = \"$APPLICATION_ID\"/" "$file"
done

# ---------------------------------------------------------------------------
#  The Google Services configuration.
# ---------------------------------------------------------------------------
echo "==> Installing the Google Services configuration"
cp tooling/google-services.json android/app/google-services.json

if [ -f android/settings.gradle.kts ]; then
    if ! grep -q "com.google.gms.google-services" android/settings.gradle.kts; then
        sed -i 's/^plugins {/plugins {\n    id("com.google.gms.google-services") version "4.4.2" apply false/' \
            android/settings.gradle.kts
    fi
elif [ -f android/settings.gradle ]; then
    if ! grep -q "com.google.gms.google-services" android/settings.gradle; then
        sed -i "0,/^plugins {/s//plugins {\n    id 'com.google.gms.google-services' version '4.4.2' apply false/" \
            android/settings.gradle
    fi
fi

if [ -f android/app/build.gradle.kts ]; then
    if ! grep -q "com.google.gms.google-services" android/app/build.gradle.kts; then
        sed -i 's/^    id("dev.flutter.flutter-plugin-loader")/    id("com.google.gms.google-services")\n    id("dev.flutter.flutter-plugin-loader")/' \
            android/app/build.gradle.kts
    fi
elif [ -f android/app/build.gradle ]; then
    if ! grep -q "com.google.gms.google-services" android/app/build.gradle; then
        sed -i "s/^    apply plugin: 'dev.flutter.flutter-plugin-loader'/    apply plugin: 'com.google.gms.google-services'\n    apply plugin: 'dev.flutter.flutter-plugin-loader'/" \
            android/app/build.gradle
    fi
fi

# ---------------------------------------------------------------------------
#  Cleartext traffic, so a local API can be reached during development.
# ---------------------------------------------------------------------------
if ! grep -q "usesCleartextTraffic" android/app/src/main/AndroidManifest.xml; then
    sed -i 's|<application|<application\n        android:usesCleartextTraffic="true"|' \
        android/app/src/main/AndroidManifest.xml
fi

# ---------------------------------------------------------------------------
#  Gradle tuning, so the build fits on a small machine.
# ---------------------------------------------------------------------------
if ! grep -q "Ennvo: tuned for small build machines" android/gradle.properties; then
    cat >> android/gradle.properties <<'GRADLE'

# --- Ennvo: tuned for small build machines -------------------------------
org.gradle.jvmargs=-Xmx3072M -XX:MaxMetaspaceSize=768M -Dfile.encoding=UTF-8
org.gradle.workers.max=2
org.gradle.parallel=true
org.gradle.caching=true
kotlin.compiler.execution.strategy=in-process
kotlin.daemon.jvmargs=-Xmx1024M
android.useAndroidX=true
android.enableJetifier=false
android.nonTransitiveRClass=true
GRADLE
fi

echo "==> Android project ready"
