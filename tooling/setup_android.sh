#!/usr/bin/env bash
# ============================================================================
#  Sets up the platform projects of the Ennvo app.
#
#  The repository keeps the Dart sources only, so the platform folders are
#  generated here. That keeps the repository small and means the platform
#  projects always match the Flutter SDK that builds them.
#
#  The script is idempotent: when the folders already exist it only applies
#  the Ennvo specific customisations.
#
#  Usage:  bash tooling/setup_android.sh [android|ios|all]
#
#  The in place edits use `perl -pi` rather than `sed -i`, because the macOS
#  runner ships the BSD `sed`, which needs a different `-i` syntax.
# ============================================================================

set -euo pipefail

cd "$(dirname "$0")/.."

TARGET="${1:-all}"

APPLICATION_ID="com.erfan.ennvoapp"
PLATFORMS="android,ios"

if [ "$TARGET" = "ios" ]; then
    PLATFORMS="ios"
elif [ "$TARGET" = "android" ]; then
    PLATFORMS="android"
fi

echo "==> Flutter SDK: $(flutter --version | head -1)"

# ---------------------------------------------------------------------------
#  Generate the platform folders when they are missing.
# ---------------------------------------------------------------------------
if [ ! -d android ] && [ ! -d ios ]; then
    echo "==> Generating the platform projects ($PLATFORMS)"
    flutter create --platforms="$PLATFORMS" --project-name ennvo --org com.erfan --no-pub .
    # `flutter create` may refresh the template files; keep our sources.
    git checkout -- lib pubspec.yaml analysis_options.yaml 2>/dev/null || true
    # The template widget test references a `MyApp` class this project does
    # not have.
    rm -f test/widget_test.dart
fi

if [ "$TARGET" != "ios" ]; then
    # -------------------------------------------------------------------------
    #  The native shell with the device-tier channel.
    # -------------------------------------------------------------------------
    echo "==> Installing the native shell"
    mkdir -p "android/app/src/main/kotlin/com/erfan/ennvoapp"
    cp tooling/MainActivity.kt "android/app/src/main/kotlin/com/erfan/ennvoapp/MainActivity.kt"
    rm -rf "android/app/src/main/kotlin/com/erfan/ennvo"

    # -------------------------------------------------------------------------
    #  The application id, the signing configuration and the release lint task
    #  are all applied by one script, so the CI, the local setup and a fresh
    #  clone stay in sync.
    # -------------------------------------------------------------------------
    echo "==> Applying the Gradle customisations"
    node tooling/patch_gradle.js .

    # -------------------------------------------------------------------------
    #  The Google Services configuration.
    # -------------------------------------------------------------------------
    echo "==> Installing the Google Services configuration"
    cp tooling/google-services.json android/app/google-services.json

    if [ -f android/settings.gradle.kts ]; then
        if ! grep -q "com.google.gms.google-services" android/settings.gradle.kts; then
            perl -0pi -e 's/^plugins \{/plugins {\n    id("com.google.gms.google-services") version "4.4.2" apply false/m' \
                android/settings.gradle.kts
        fi
    elif [ -f android/settings.gradle ]; then
        if ! grep -q "com.google.gms.google-services" android/settings.gradle; then
            perl -0pi -e "s/^plugins \{/plugins {\n    id 'com.google.gms.google-services' version '4.4.2' apply false/m" \
                android/settings.gradle
        fi
    fi

    if [ -f android/app/build.gradle.kts ]; then
        if ! grep -q "com.google.gms.google-services" android/app/build.gradle.kts; then
            perl -0pi -e 's/^    id\("dev\.flutter\.flutter-plugin-loader"\)/    id("com.google.gms.google-services")\n    id("dev.flutter.flutter-plugin-loader")/m' \
                android/app/build.gradle.kts
        fi
    elif [ -f android/app/build.gradle ]; then
        if ! grep -q "com.google.gms.google-services" android/app/build.gradle; then
            perl -0pi -e "s/^    apply plugin: 'dev\.flutter\.flutter-plugin-loader'/    apply plugin: 'com.google.gms.google-services'\n    apply plugin: 'dev.flutter.flutter-plugin-loader'/m" \
                android/app/build.gradle
        fi
    fi

    # -------------------------------------------------------------------------
    #  Cleartext traffic, so a local API can be reached during development.
    # -------------------------------------------------------------------------
    if ! grep -q "usesCleartextTraffic" android/app/src/main/AndroidManifest.xml; then
        perl -0pi -e 's|<application|<application\n        android:usesCleartextTraffic="true"|' \
            android/app/src/main/AndroidManifest.xml
    fi

    # -------------------------------------------------------------------------
    #  Gradle tuning, so the build fits on a small machine.
    #
    #  The values are replaced rather than appended, so the file never ends
    #  up with the same key twice.
    # -------------------------------------------------------------------------
    echo "==> Tuning Gradle"
    perl -pi -e 's/^org\.gradle\.jvmargs=.*$/org.gradle.jvmargs=-Xmx3072M -XX:MaxMetaspaceSize=768M -Dfile.encoding=UTF-8/' \
        android/gradle.properties
    if ! grep -q "Ennvo: tuned for small build machines" android/gradle.properties; then
        cat >> android/gradle.properties <<'GRADLE'

# --- Ennvo: tuned for small build machines -------------------------------
org.gradle.workers.max=2
org.gradle.parallel=true
org.gradle.caching=true
kotlin.compiler.execution.strategy=in-process
kotlin.daemon.jvmargs=-Xmx1024M
android.enableJetifier=false
android.nonTransitiveRClass=true
GRADLE
    fi

    echo "==> Android project ready"
fi

if [ "$TARGET" = "ios" ]; then
    echo "==> iOS project ready"
fi
