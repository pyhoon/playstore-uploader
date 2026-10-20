# playstore-uploader

`aabtool` is a small B4J command-line utility that uploads an Android App Bundle (`.aab`) to Google Play with a Google Cloud service account. It creates a Play edit, uploads the bundle, optionally assigns it to a track, and commits the edit. If any step fails, the edit is aborted so no partial release is left open.

## How it works

1. Builds a signed JWT assertion from the service account JSON (`RS256`).
2. Exchanges the assertion for an OAuth2 access token.
3. Creates an edit session for the application.
4. Uploads the `.aab` and reads the new `versionCode`.
5. Optionally updates a track with the new version code.
6. Commits the edit.
7. Deletes the edit on failure.

API endpoints used:

| Step | Request |
| --- | --- |
| Token | `POST https://oauth2.googleapis.com/token` |
| Create edit | `POST https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{package}/edits` |
| Upload bundle | `POST https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{package}/edits/{editId}/bundles?uploadType=media` |
| Update track | `PUT https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{package}/edits/{editId}/tracks/{track}` |
| Commit edit | `POST https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{package}/edits/{editId}:commit` |
| Abort edit | `DELETE https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{package}/edits/{editId}` |

## Requirements

- B4J 10.7 or newer.
- Java 19 or newer to run the built jar (the project is compiled with Java 19).
- An app that already exists in Google Play Console.
- A Google Cloud service account with access to that app.
- An `.aab` signed with your upload key.

## Google Play setup

### 1. Enable the Android Publisher API

In [Google Cloud Console](https://console.cloud.google.com/):

1. Select or create a project.
2. Open **APIs & Services > Library**.
3. Search for **Google Play Android Developer API**.
4. Enable it.

### 2. Create a service account and JSON key

1. Open **IAM & Admin > Service Accounts**.
2. Create a service account (no GCP roles are required).
3. Open the new account, go to **Keys**, and choose **Add key > Create new key > JSON**.
4. Download the JSON key and store it outside the repository.

Only `client_email` and `private_key` from the JSON file are used by `aabtool`.

### 3. Grant the service account access in Play Console

1. Open **Play Console > Users and permissions > Invite new users**.
2. Enter the service account email (`...@....iam.gserviceaccount.com`).
3. Under **App permissions**, select the application and grant:
   - **Release to testing tracks** (internal, alpha, beta).
   - **Release apps to production** only if you upload to `production`.
4. Send the invitation.

Access can take a few minutes to propagate. Until then, token exchange fails with `invalid_grant: account not found`.

## Build

Open `source/playstore-uploader.b4j` in B4J and use the included **Build only** macro, or run:

```powershell
& "C:\Program Files\B4X\B4J\B4JBuilder.exe" `
  -Task=Build `
  -BaseFolder="C:\Projects\playstore-uploader\source" `
  -Obfuscate=False `
  -Output=aabtool
```

The jar is written to `source\Objects\aabtool.jar`. The examples below use `aabtool.jar`.

The project uses `#MergeLibraries: True`, so the built jar includes `jCore`, `JavaObject`, `jOkHttpUtils2`, and the JSON library.

## Usage

```text
java -jar aabtool.jar --app-bundle <file.aab> --application-package <package> [options]
java -jar aabtool.jar <file.aab> <package> [key.json]
```

### Options

| Option | Required | Description |
| --- | --- | --- |
| `--app-bundle <path>` | Yes | Path to the `.aab` file. Positional form: first argument. |
| `--application-package <name>` | Yes | Application ID, for example `com.example.app`. Positional form: second argument. |
| `--secret-file <path>` | No | Service account JSON. Default: `C:\tools\google-key.json`. Positional form: third argument. |
| `--track <track>` | No | Track ID such as `internal`, `alpha`, `beta`, `production`, or a custom track. If omitted, the bundle is uploaded but not assigned to a track. |
| `--status <status>` | No | Release status for the track. Default: `completed`. Use `draft` to save without releasing. |
| `--application-name <name>` | No | Accepted and logged for compatibility; not sent to Google. |
| `app-bundle-upload` | No | Optional command token used by wrapper scripts; ignored by the tool. |

### Examples

Upload to the internal track:

```powershell
java -jar aabtool.jar `
  --app-bundle "C:\build\app-release.aab" `
  --application-package "com.example.app" `
  --secret-file "C:\keys\google-key.json" `
  --track internal
```

Upload to production (100% rollout after review):

```powershell
java -jar aabtool.jar --app-bundle "C:\build\app-release.aab" --application-package "com.example.app" --secret-file "C:\keys\google-key.json" --track production --status completed
```

Upload without assigning a track:

```powershell
java -jar aabtool.jar --app-bundle "C:\build\app-release.aab" --application-package "com.example.app" --secret-file "C:\keys\google-key.json"
```

Positional form:

```powershell
java -jar aabtool.jar "C:\build\app-release.aab" "com.example.app" "C:\keys\google-key.json"
```

The tool logs the uploaded `versionCode` and exits. A successful run ends with:

```text
Done: App Bundle uploaded and edit committed.
```

A run that fails during the upload flow ends with:

```text
Done: upload failed.
```

Argument and file validation errors exit earlier with an `Error: ...` message.

## Use after a B4A build

B4A supports an `after packager` custom build action, which runs after the AAB is signed. Add it to the main module to upload straight from **Project > Build App Bundle**:

```b4x
#If RELEASE
#CustomBuildAction: after packager, %JAVABIN%\java.exe, -jar "C:\tools\aabtool.jar" --app-bundle "%PROJECT%\Objects\MyApp.aab" --application-package "com.example.app" --secret-file "%USERPROFILE%\keys\google-key.json" --track internal
#End If
```

B4A names the bundle after the project (normally `<project name>.aab`) in the `Objects` folder, so replace `MyApp.aab` with the file shown in the build log. The action's working directory is `Objects`, and `%JAVABIN%` is the JDK configured in B4A.

- Do not use step `5`; it runs after the APK is installed on a device.
- The action blocks the IDE until the upload finishes.

### One-click build and upload

[build-upload.bat](build-upload.bat) builds the AAB with `B4ABuilder -Task=BuildBundle` and then uploads it with `aabtool`. Copy it into the B4A project folder (next to the `.b4a` file) and edit the paths, package name, track, and `OBFUSCATE` setting at the top.

Run it from a terminal, or add this macro to the `Main` module to run it from the IDE title bar:

```b4x
#Macro: Title, Build AAB and Upload, ide://run?File=%COMSPEC%&Args=/c&Args=..\build-upload.bat&NoTimeout=True
```

The script writes the build and upload log to `build-upload.log` in the project folder and opens it on failure. It treats a missing success marker as a failure because `aabtool` exits `0` even when the upload fails.

To build the bundle without uploading:

```b4x
#Macro: Title, Build AAB, ide://run?File=%B4X%\B4ABuilder.exe&Args=-Task%3DBuildBundle&Args=-BaseFolder%3D..&NoTimeout=True
```

Obfuscated build:

```b4x
#Macro: Title, Build AAB (obfuscated), ide://run?File=%B4X%\B4ABuilder.exe&Args=-Task%3DBuildBundle&Args=-BaseFolder%3D..&Args=-Obfuscate%3DTrue&NoTimeout=True
```

For an obfuscated one-click build and upload, set `OBFUSCATE=True` at the top of `build-upload.bat`. `#Macro` requires B4A 13.3 or newer.

### Build from a script or CI

Custom build actions are not executed by command-line builds, so build and upload explicitly:

```powershell
# Build the AAB with B4A first, then upload it.
java -jar "C:\tools\aabtool.jar" `
  --app-bundle "C:\Projects\MyApp\Objects\MyApp.aab" `
  --application-package "com.example.app" `
  --secret-file "C:\keys\google-key.json" `
  --track internal
```

## CI notes

- The tool currently exits with code `0` even when the upload fails. In CI, require the success marker in the log:

```powershell
$output = & java -jar aabtool.jar --app-bundle "app.aab" --application-package "com.example.app" --secret-file "key.json" 2>&1
$output | Write-Output
if (($output -join "`n") -notmatch "Done: App Bundle uploaded and edit committed") { exit 1 }
```

- Never store the service account JSON in the repository. Provide it through a CI secret and write it to a temporary file.
- If the build machine uses a proxy, pass Java proxy properties, for example `-Dhttps.proxyHost=proxy -Dhttps.proxyPort=8080`.

## Troubleshooting

| Log message | Cause | Fix |
| --- | --- | --- |
| `invalid_grant: Invalid grant: account not found` | The service account is not a Play Console user, or access has not propagated. | Invite the service account email in Play Console and retry after a few minutes. |
| `401 Unauthorized` | Token invalid, wrong key, or system clock is far off. | Check the JSON key, system time, and project. |
| `403 Forbidden` / `The caller does not have permission` | Missing Play Console permission or the API is not enabled. | Enable the Android Publisher API and grant the required app permissions. |
| `404` / `Application not found` | Wrong package name or the app is not in the account. | Verify `--application-package` and the service account's app access. |
| `versionCode ... has already been used` | The bundle's version code was already uploaded. | Increase `versionCode` and rebuild the bundle. |
| `signed with the wrong key` | The AAB is signed with a key that does not match the upload certificate. | Sign with the correct upload key. |
| `Bundle is not a valid` / `invalid bundle` | The file is not a valid `.aab`. | Rebuild the app bundle. |
| `UnsupportedClassVersionError` | Running with an older Java. | Use Java 19 or newer. |
| Request hangs or times out | Network or proxy issue. | Allow HTTPS access to Google endpoints or configure Java proxy properties. |

## Important Google Play rules

- The API cannot create a new app. The app must exist in Play Console, and the first release must be uploaded manually.
- The package name must match the app exactly.
- Every upload needs a `versionCode` higher than any previously uploaded version code.
- If Play App Signing is enabled, upload an AAB signed with your upload key.
- `--status completed` to production submits the release for review and targets a full rollout. Staged rollouts (`inProgress` with a user fraction) and release notes are not handled by this tool; use Play Console for those.

## Security

- Keep the service account JSON private and out of version control.
- Grant the service account only the permissions and apps it needs.
- Rotate or revoke keys from Google Cloud Console if a key is exposed.
- Do not pass secrets in shared command history on untrusted machines.

## Project layout

```text
build-upload.bat                Template B4A build/upload script
source/playstore-uploader.b4j   B4J source
source/Objects/                 Build output
source/AutoBackups/             B4J automatic backups (ignored by git)
```

## License

MIT. See [LICENSE](LICENSE).
