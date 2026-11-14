/**
 * Switches the release build over to an upload key.
 *
 * Run it once a keystore is available:
 *
 *   1. put the keystore at `android/app/upload-keystore.jks`
 *   2. create `android/key.properties`:
 *
 *        storeFile=upload-keystore.jks
 *        storePassword=...
 *        keyAlias=...
 *        keyPassword=...
 *
 *   3. run `node tooling/enable_release_signing.js`
 *
 * The four values are also read from the repository secrets by the Android
 * workflow, so a pull request build is signed the same way.
 */
const fs = require('fs');
const path = require('path');

const root = process.argv[2] || path.join(__dirname, '..');
const KTS = path.join(root, 'android', 'app', 'build.gradle.kts');

if (!fs.existsSync(KTS)) {
  console.error('android/app/build.gradle.kts not found.');
  process.exit(1);
}

const signingKts = `    signingConfigs {
        create("release") {
            val keyPropertiesFile = rootProject.file("key.properties")
            if (keyPropertiesFile.exists()) {
                val keyProperties = java.util.Properties()
                keyProperties.load(keyPropertiesFile.inputStream())
                storeFile = keyProperties.getProperty("storeFile")?.let { rootProject.file(it) }
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

`;

let content = fs.readFileSync(KTS, 'utf8');

if (!content.includes('signingConfigs {')) {
  content = content.replace(
    /(\n\s*)buildTypes\s*\{/,
    `\n${signingKts}$1buildTypes {`,
  );
}

content = content.replace(
  /signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)/,
  `signingConfig = if (rootProject.file("key.properties").exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }`,
);

fs.writeFileSync(KTS, content, 'utf8');
console.log('==> Release signing enabled');
console.log('    add android/key.properties with the four values to activate it');
