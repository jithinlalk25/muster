# Releasing Muster

Muster is distributed as a **Developer ID-signed, notarized `.dmg`** on GitHub Releases,
installed and updated through a **Homebrew cask**. The Mac App Store is not an option:
Muster edits `~/.claude/settings.json`, spawns the `muster-hook` helper, and talks over a
UNIX socket — all of which the App Store sandbox forbids.

---

## One-time setup

### 1. Apple Developer Program + certificate
- Enroll in the [Apple Developer Program](https://developer.apple.com/programs/) ($99/yr).
- Create a **Developer ID Application** certificate and import it into your login keychain
  (Xcode → Settings → Accounts → Manage Certificates → +, or the Developer portal).
- Confirm it's present:
  ```bash
  security find-identity -v -p codesigning | grep "Developer ID Application"
  ```
  Note the full identity string, e.g. `Developer ID Application: Jithin Lal K (AB12CD34EF)`.

### 2. notarytool credentials (stored once in the keychain)
Create an **app-specific password** at <https://account.apple.com> (Sign-In and Security →
App-Specific Passwords), then:
```bash
xcrun notarytool store-credentials "muster-notary" \
  --apple-id "you@example.com" \
  --team-id  "AB12CD34EF" \
  --password "abcd-efgh-ijkl-mnop"   # the app-specific password
```
`muster-notary` is the profile name you'll pass as `MUSTER_NOTARY_PROFILE`.

### 3. GitHub repo (hosts the release assets)
```bash
gh repo create jithinlalk25/muster --public --source . --remote origin --push
```
The cask downloads from this repo's Releases, so it must be **public**.

### 4. Homebrew tap (hosts the cask)
```bash
gh repo create jithinlalk25/homebrew-tap --public --clone
# copy this repo's Casks/muster.rb into the tap and push:
cp Casks/muster.rb ../homebrew-tap/Casks/muster.rb
(cd ../homebrew-tap && git add Casks/muster.rb && git commit -m "add muster cask" && git push)
```
Users then install with `brew install --cask jithinlalk25/homebrew-tap/muster`.

---

## Cutting a release

1. **Bump the version** in the single source of truth:
   `Sources/MusterCore/Version.swift` (`build-app.sh` and `release.sh` read it).
   Commit and tag intent later in step 4.

2. **Build, sign, notarize, staple, package:**
   ```bash
   MUSTER_SIGN_ID="Developer ID Application: Jithin Lal K (AB12CD34EF)" \
   MUSTER_NOTARY_PROFILE="muster-notary" \
     ./Scripts/release.sh
   ```
   Produces `dist/Muster-<version>.dmg` (notarized + stapled) and prints the **sha256**.

3. **Publish the GitHub Release:**
   ```bash
   gh release create v<version> "dist/Muster-<version>.dmg" \
     --title "Muster <version>" --generate-notes
   ```

4. **Update the tap** — set `version` and `sha256` in the tap's `Casks/muster.rb`
   (the values `release.sh` printed), then commit + push the tap.

Done. Users get it with:
```bash
brew install --cask jithinlalk25/homebrew-tap/muster   # first install
brew upgrade --cask muster                             # updates
```

---

## Notes
- **Universal binary:** `build-app.sh` builds `--arch arm64 --arch x86_64`, so the release
  runs on both Apple Silicon and Intel.
- **Launch-at-login:** `SMAppService` only works for a signed app in a stable location.
  Once installed via the cask (into `/Applications`), the "Launch at login" toggle works —
  the errors seen when running the raw dev binary do not occur for the shipped app.
- **Hook path stability:** `HookInstaller` writes the app's absolute path into
  `settings.json`. Installing into `/Applications` (as the cask does) keeps that path valid
  across in-place upgrades. If a user *moves* the app, they re-run Settings… → Install hooks.
- **Auto-update beyond brew:** for non-brew users, add [Sparkle](https://sparkle-project.org)
  and a "Check for Updates…" menu item later; the cask channel covers the developer audience today.
