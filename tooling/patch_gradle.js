/**
 * Applies the Ennvo specific customisations to the Android Gradle project.
 *
 * Doing this in one place keeps the CI, the local setup and a fresh clone
 * in sync:
 *
 *   • the application id stays `com.erfan.ennvoapp`, so the app keeps the
 *     existing Firebase registration and the push tokens
 *   • the release build is signed with the upload key when
 *     `android/key.properties` exists, and with the debug key otherwise
 *   • the release lint task is disabled, because the Kotlin compiler that
 *     ships with the Flutter template is not compatible with the lint API
 *     in AGP 9
 *
 * Usage:  node tooling/patch_gradle.js [projectRoot]
 */
const fs = require('fs');
const path = require('path');

const root = process.argv[2] || path.join(__dirname, '..');
const appDir = path.join(root, 'android', 'app');

const APPLICATION_ID = 'com.erfan.ennvoapp';

const KTS = path.join(appDir, 'build.gradle.kts');
const GROOVY = path.join(appDir, 'build.gradle');

if (!fs.existsSync(KTS) && !fs.existsSync(GROOVY)) {
  console.error('android/app/build.gradle not found — run flutter create first.');
  process.exit(1);
}

// ---------------------------------------------------------------------------
//  The Kotlin DSL version.
// ---------------------------------------------------------------------------
const signingKts = `    signingConfigs {
        create("release") {
            val keyPropertiesFile = rootProject.file("key.properties")
            if (keyPropertiesFile.exists()) {
                val keyProperties = java.util.Properties()
                keyProperties.load(keyPropertiesFile.inputStream())
                storeFile = keyProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

`;

const lintKts = `    lint {
        // The Kotlin compiler that ships with the Flutter template is not
        // compatible with the lint API in AGP 9: the release lint task fails
        // inside the Firebase plugins with a NoSuchMethodError.
        checkReleaseBuilds = false
        abortOnError = false
    }

`;

function patchKts(content) {
  let out = content;

  // --- the application id --------------------------------------------
  out = out.replace(
    /applicationId\s*=\s*"[^"]*"/g,
    `applicationId = "${APPLICATION_ID}"`,
  );
  out = out.replace(/namespace\s*=\s*"[^"]*"/g, `namespace = "${APPLICATION_ID}"`);

  // --- the signing configuration --------------------------------------
  if (!out.includes('signingConfigs {')) {
    out = out.replace(/(\n\s*)buildTypes\s*\{/, `\n${signingKts}$1buildTypes {`);
  }
  if (!out.includes('checkReleaseBuilds = false')) {
    out = out.replace(/(\n\s*)buildTypes\s*\{/, `\n${lintKts}$1buildTypes {`);
  }
  out = out.replace(
    /signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)/,
    `signingConfig = if (rootProject.file("key.properties").exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }`,
  );

  return out;
}

// ---------------------------------------------------------------------------
//  The Groovy DSL version.
// ---------------------------------------------------------------------------
const signingGroovy = `    signingConfigs {
        release {
            if (file("key.properties").exists()) {
                def keyProperties = new Properties()
                keyProperties.load(new File(rootProject.projectDir, "key.properties").newInputStream())
                storeFile keyProperties['storeFile']
                storePassword keyProperties['storePassword']
                keyAlias keyProperties['keyAlias']
                keyPassword keyProperties['keyPassword']
            }
        }
    }

`;

const lintGroovy = `    lint {
        checkReleaseBuilds false
        abortOnError false
    }

`;

function patchGroovy(content) {
  let out = content;

  out = out.replace(
    /applicationId\s+["'][^"']*["']/g,
    `applicationId '${APPLICATION_ID}'`,
  );
  out = out.replace(
    /namespace\s+["'][^"']*["']/g,
    `namespace '${APPLICATION_ID}'`,
  );

  if (!out.includes('signingConfigs {')) {
    out = out.replace(
      /(\n\s*)buildTypes\s*\{/,
      `\n${signingGroovy}$1buildTypes {`,
    );
  }
  if (!out.includes('checkReleaseBuilds false')) {
    out = out.replace(
      /(\n\s*)buildTypes\s*\{/,
      `\n${lintGroovy}$1buildTypes {`,
    );
  }
  out = out.replace(
    /signingConfig\s+signingConfigs\.debug/,
    `signingConfig rootProject.file("key.properties").exists() ? signingConfigs.release : signingConfigs.debug`,
  );

  return out;
}

if (fs.existsSync(KTS)) {
  const before = fs.readFileSync(KTS, 'utf8');
  const after = patchKts(before);
  if (before !== after) {
    fs.writeFileSync(KTS, after, 'utf8');
    console.log('  patched android/app/build.gradle.kts');
  } else {
    console.log('  android/app/build.gradle.kts is already up to date');
  }
}

if (fs.existsSync(GROOVY)) {
  const before = fs.readFileSync(GROOVY, 'utf8');
  const after = patchGroovy(before);
  if (before !== after) {
    fs.writeFileSync(GROOVY, after, 'utf8');
    console.log('  patched android/app/build.gradle');
  } else {
    console.log('  android/app/build.gradle is already up to date');
  }
}

console.log('==> Gradle project ready');
