# Sign the app in release mode (for Google Play)

Your AAB was rejected because it was signed in **debug** mode. Follow these steps **once** to create a release keystore and then build a correctly signed AAB.

---

## Step 1: Create a release keystore

In a terminal, from your **project root** (Dyganox-9), run:

```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- You will be asked for a **keystore password** and a **key password** (you can use the same).
- Fill in your name, organization, etc. (required by the tool).
- **Keep the keystore and passwords safe.** You need them for every future Play Store update. If you lose them, you cannot update the same app on Play.

---

## Step 2: Create `key.properties`

1. In the **android** folder, copy the example file:
   - Copy `android/key.properties.example` to `android/key.properties`.

2. Open **android/key.properties** and set **your** values:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=app/upload-keystore.jks
```

- Use the same passwords you set in Step 1.
- `storeFile` is relative to the **android** folder. If you put the keystore at `android/app/upload-keystore.jks`, use `app/upload-keystore.jks`.

**Do not commit `key.properties` or `upload-keystore.jks` to git** (they are already in `.gitignore`).

---

## Step 3: Build the release AAB

From the **project root**:

```bash
flutter clean
flutter build appbundle --release
```

The signed AAB will be at:

**`build/app/outputs/bundle/release/app-release.aab`**

Upload this file to Google Play Console for internal testing. It will be signed in **release** mode and the previous error will be resolved.

---

## If you already have a keystore

If you created a keystore elsewhere or with a different path/alias:

1. Put the `.jks` file in the `android` folder (e.g. `android/my-release.jks`).
2. In **android/key.properties**, set:
   - `storeFile=my-release.jks` (path relative to **android**)
   - `keyAlias=` the alias you used when creating the keystore
   - `storePassword=` and `keyPassword=` as set for that keystore.

Then run `flutter build appbundle --release` again.
