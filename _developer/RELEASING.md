# Releasing SDR9700

Every GitHub release must include substantive, maintainer-readable release
notes. GitHub-generated notes may be used as source material, but a changelog
link by itself is not an acceptable release description.

Before running the macOS release workflow, configure the `macos_release`
environment with a `main` branch restriction, required maintainer review, and
environment-scoped Apple signing and notarization secrets. Remove any
repository-scoped copies of those secrets. See the [macOS packaging guide](../resources/packaging/macos/README.md)
for the required names and setup details.

## Version naming

SDR9700 versions use `YY.M.R`, where `YY` is the final two digits of the
calendar year, `M` is the numeric month without a leading zero, and `R` is the
release sequence for that month. For example, the first September 2026 release
is `26.9.1`.

Stable releases use the numeric version directly, for example `26.9.1`.
Prereleases append a hyphenated prerelease identifier, starting with
`-beta.1` and incrementing the final number for each subsequent beta, for
example `26.9.1-beta.1` and `26.9.1-beta.2`.

Keep the CMake project version numeric because CMake's `project(VERSION)`
field does not accept prerelease suffixes. For a beta of `26.9.1`, set the
project version to `26.9.1` and `SDR9700_DISPLAY_VERSION` to the complete
prerelease version such as `26.9.1-beta.1`.

Do not include a leading `v` in `SDR9700_DISPLAY_VERSION`. The application
adds that prefix when it builds the title bar, which must read
`SDR9700 v<version>` (for example, `SDR9700 v26.9.1-beta.1`).

Git tags always add a leading `v`. A beta release therefore uses a tag such
as `v26.9.1-beta.1`, the title `SDR9700 v26.9.1-beta.1`, and must be marked as a
GitHub prerelease. Sign release tags and verify their signatures before
creating a draft:

```bash
git tag -s v26.9.1-beta.1 -m "SDR9700 v26.9.1-beta.1"
git verify-tag v26.9.1-beta.1
git push origin v26.9.1-beta.1
```

## Release checklist

1. Set the numeric CMake project version and `SDR9700_DISPLAY_VERSION` in
   `CMakeLists.txt`. Include the prerelease suffix only in the display version.
2. Run a clean Release build with `make release`.
3. Run the complete test suite with
   `ctest --test-dir _workspace/build --output-on-failure`.
4. Write release notes that summarize user-visible highlights, improvements,
   and fixes since the previous release. End with the full changelog comparison
   link. Generated notes may be edited into the authored notes, but must not be
   published without maintainer review.
5. Commit and push the version change to `main`. Create and push a signed
   `v<version>` tag at that exact commit, then verify the tag signature and
   that its commit matches `main`.
6. Create a **draft** GitHub release for that existing tag with the title
   `SDR9700 v<version>`, the authored notes, and the correct stable/prerelease
   setting. Do not publish the draft yet. For example:

   ```bash
   gh release create v26.9.1-beta.1 --draft --prerelease \
     --title "SDR9700 v26.9.1-beta.1" --notes-file <file>
   ```

7. From the repository's `main` branch, manually dispatch the **Release macOS
   DMG** workflow for that existing tag. The workflow packages the signed tag
   and attaches the Apple Silicon DMG only after build, tests, bundle checks,
   signing, and notarization succeed. Linux release packages are not part of
   the current release plan; Linux users build from source.
8. Read the draft release back with `gh release view` and verify its draft
   state, stable/prerelease state, title, tag, authored notes, and attached
   DMG. Review the packaged DMG before publishing the draft.
9. Publish the draft only after those checks pass, then confirm the published
   release page and DMG are available.
