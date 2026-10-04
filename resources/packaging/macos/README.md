# macOS release packaging

SDR9700's `Release macOS DMG` GitHub Actions workflow is started manually from
`main` with a `release_tag` input. The tag must be a signed annotated tag at
the exact selected `main` commit and match `SDR9700_DISPLAY_VERSION` with a
leading `v`, for example `v26.9.1` or `v26.9.1-beta.1`. A draft GitHub Release
for that tag must already exist. The workflow builds, tests, audits, signs,
notarizes, and staples the Apple Silicon DMG, then attaches it to that draft.
It does not publish the Release. After the workflow succeeds and the asset and
release notes have been reviewed, a maintainer publishes the draft.

Configure the `macos_release` GitHub Actions environment with a deployment
branch restriction allowing only `main` and a required maintainer review. The
signing and notarization secrets below currently remain at repository scope at
the maintainer's request; the release workflow can use them there. Their move
to environment scope is deferred. The workflow's `main` guard and environment
branch restriction must both remain in place. The pinned Qt setup checks the
exact package revision, and the bundle audit checks its QtCore version,
self-contained dependencies, and minimum macOS version before signing.

The official DMG requires macOS 15.0 or newer, recorded in
`resources/packaging/macos/release_pin.env`. Qt 6.12 itself supports macOS
14.4, but bundled Homebrew libraries from the macos-15 runner require 15.0.
The bundle audit compares the app's declared minimum with the release pin and
rejects any bundled Mach-O binary that needs a newer system.

The release workflow requires these GitHub Actions secrets:

- `APPLE_CERT_BASE64`: Base64-encoded PKCS#12 (`.p12`) export containing the
  Developer ID Application certificate and its private key.
- `APPLE_CERT_PASSWORD`: Password assigned to the `.p12` export.
- `APPLE_ID`: Apple Account email used for notarization.
- `APPLE_APP_PASSWORD`: App-specific password created for notarization.
- `APPLE_TEAM_ID`: Ten-character Apple Developer Team ID.

Create the certificate secret on macOS without committing the exported
certificate:

```bash
base64 < DeveloperIDApplication.p12 | tr -d '\n' | pbcopy
```

Paste the clipboard contents into the `APPLE_CERT_BASE64` environment secret,
then securely remove the temporary `.p12` if it is no longer needed. Never
store certificates, private keys, or notarization passwords in the repository.

For a release whose version has been committed to `main`, create and push the
signed tag and prepare the draft with reviewed release notes. Run the workflow
from `main` using the matching tag:

```bash
gh workflow run release_macos.yml --ref main -f release_tag=v<version>
```

The release stays in draft if any build, test, audit, signing, or notarization
step fails. After the workflow succeeds, inspect the draft asset and publish
it with `gh release edit v<version> --draft=false`.

For local packaging, set `SDR9700_SIGN_IDENTITY` to the complete Developer ID
Application identity reported by `security find-identity -v -p codesigning`,
then run the pinned Qt setup and rebuild before packaging. `make bundle` and
`make release-dmg` use the `macdeployqt` from the Qt kit recorded in the CMake
cache and require that kit's installed package revision to match
`_developer/qt/qt_pin.env`; another Qt installation on `PATH` is ignored.

```bash
make qt-setup
export CMAKE_PREFIX_PATH="$(make -s qt-prefix)"
```

Then run:

```bash
make release
make release-dmg
make verify-bundle
```

To notarize the DMG locally, store a `notarytool` Keychain profile, set
`SDR9700_NOTARY_PROFILE` to its name, and run:

```bash
make notarize DMG=_workspace/build/package/SDR9700-<version>-macOS-apple-silicon.dmg
```
