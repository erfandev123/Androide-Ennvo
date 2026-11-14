/**
 * Applies the Ennvo specific customisations to the Android Gradle project.
 *
 * Doing this in one place keeps the CI, the local setup and a fresh clone
 * in sync:
 *
 *   • the application id stays `com.erfan.ennvoapp`, so the app keeps the
 *     existing Firebase registration and the push tokens
 *   • the Google Services plugin is applied, so the Firebase configuration
 *     is read
 *   • the release lint task is disabled, because the Kotlin compiler that
 *     ships with the Flutter template is not compatible with the lint API
 *     in AGP 9
 *
 * The release build is signed with the debug key, which is what the Flutter
 * template does. Run `node tooling/enable_release_signing.js` to switch it
 * to an upload key.
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
  console.error('android/app/build.gradle not found - run flutter create first.');
  process.exit(1);
}

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

  // --- the application id ---------------------------------------------
  out = out.replace(
    /applicationId\s*=\s*"[^"]*"/g,
    `applicationId = "${APPLICATION_ID}"`,
  );
  out = out.replace(/namespace\s*=\s*"[^"]*"/g, `namespace = "${APPLICATION_ID}"`);

  // --- the Google Services plugin --------------------------------------
  if (!out.includes('com.google.gms.google-services')) {
    out = out.replace(
      /(id\("com\.android\.application"\)\n)/,
      '$1    id("com.google.gms.google-services")\n',
    );
  }

  // --- the release lint task ------------------------------------------
  if (!out.includes('checkReleaseBuilds = false')) {
    out = out.replace(/(\n\s*)buildTypes\s*\{/, `\n${lintKts}$1buildTypes {`);
  }

  return out;
}

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

  if (!out.includes('com.google.gms.google-services')) {
    out = out.replace(
      /(apply plugin: 'com\.android\.application'\n)/,
      "$1apply plugin: 'com.google.gms.google-services'\n",
    );
  }

  if (!out.includes('checkReleaseBuilds false')) {
    out = out.replace(
      /(\n\s*)buildTypes\s*\{/,
      `\n${lintGroovy}$1buildTypes {`,
    );
  }

  return out;
}

for (const [file, patch] of [
  [KTS, patchKts],
  [GROOVY, patchGroovy],
]) {
  if (!fs.existsSync(file)) continue;
  const before = fs.readFileSync(file, 'utf8');
  const after = patch(before);
  if (before !== after) {
    fs.writeFileSync(file, after, 'utf8');
    console.log(`  patched ${path.relative(root, file)}`);
  } else {
    console.log(`  ${path.relative(root, file)} is already up to date`);
  }
}

console.log('==> Gradle project ready');
