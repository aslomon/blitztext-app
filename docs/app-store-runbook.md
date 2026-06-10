# App Store Runbook (for the `rede` spin-off)

Everything between "the code is ready" and "the app is on the Mac App Store / notarized for
direct download". Most steps need the **Apple Developer Program account** (99 €/year) and cannot
be automated from this repo. Companion docs: `PLAN-updates-and-distribution.md` (strategy),
`release-process.md` (Sparkle/direct-distribution flow).

## 0. Account & identity (manual, one-time)

- [ ] Enroll in the Apple Developer Program (individual or the UG as organization — an
      organization needs a D-U-N-S number; individual is faster).
- [ ] Create certificates in the developer portal:
  - **Developer ID Application** — direct distribution (Sparkle path)
  - **Apple Distribution** + **Mac Installer Distribution** — Mac App Store path
- [ ] Register the bundle IDs: `app.rede.mac` (+ `.tests` is not needed in the portal).
- [ ] App Store Connect: create the app record "rede", reserve the name (App Store names are
      unique per storefront — verify "rede" is free; have a fallback like "rede – Diktat & KI").
- [ ] Create an App Store Connect **API key** (for `notarytool` and CI uploads).

## 1. Direct distribution first (notarized Sparkle build)

This is the primary channel (plan decision D7) and the faster way to "other people can install".

- [ ] Switch release signing from the local dev cert to **Developer ID Application**
      (`build.sh` release path; keep the local-cert fallback for development).
- [ ] Helper hardening: sign `Contents/Helpers/llama-server` + dylibs with hardened runtime and
      the `com.apple.security.cs.disable-library-validation` entitlement (documented in
      `build.sh` comments — required because the helper loads locally-built dylibs).
- [ ] Sparkle components: hardened runtime on XPC services / `Autoupdate` / `Updater.app`
      (already wired in `build.sh sign_sparkle_framework`; flip to the Developer ID identity).
- [ ] Notarize: `xcrun notarytool submit rede-<v>.zip --keychain-profile … --wait`, then
      `xcrun stapler staple rede.app`, re-zip the stapled app for the release asset.
- [ ] Verify on a clean Mac: `spctl -a -t exec -vv rede.app` accepts; first launch has no
      Gatekeeper friction; Accessibility grant survives an auto-update cycle.

## 2. Mac App Store variant (decision gate — see plan Phase 6)

Hard requirements that change the build:

- [ ] **App Sandbox ON** in a dedicated MAS entitlements variant:
  - `com.apple.security.app-sandbox` = true
  - `com.apple.security.device.audio-input` = true (exists)
  - `com.apple.security.network.client` = true (exists)
  - `com.apple.security.network.server` = true (llama-server binds localhost)
  - helper child: `com.apple.security.inherit` = true (llama-server runs inside the app sandbox)
- [ ] **No Sparkle in the MAS build**: compile with `SPARKLE_ENABLED` removed from
      `SWIFT_ACTIVE_COMPILATION_CONDITIONS` (already architected — `UpdateService.isAvailable`
      hides every update surface) and do NOT embed the Sparkle package product.
- [ ] Data location: the sandbox container moves Application Support — ship a one-shot import
      from the non-sandboxed path or accept fresh state (decide before submission).
- [ ] Model downloads (GGUF/CoreML) land in the container — verify free-space checks still work.

### Review risks to plan around (honest assessment)

| Area                                        | Risk                                                                                                                             | Mitigation                                                                                                        |
| ------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Auto-paste via synthetic Cmd+V + AX readers | **High** — Accessibility-dependent core flows have shipped on MAS (window managers, clipboard tools), but review is inconsistent | Copy-only fallback already exists; be ready to ship MAS with "kopiert in die Zwischenablage" as the default story |
| Bring-your-own OpenAI key                   | Medium                                                                                                                           | Precedents exist; emphasize local-first defaults, key optional                                                    |
| Subprocess llama-server                     | Low-medium                                                                                                                       | Sandbox-inherited child processes are allowed; document clearly in review notes                                   |
| Global hotkeys (NSEvent monitors)           | Low                                                                                                                              | Modifier-only monitors are sandbox-tolerant                                                                       |

## 3. App Store Connect metadata

- [ ] Privacy nutrition label: **Data Not Collected** (truthful: no telemetry, no accounts;
      OpenAI traffic is user-initiated with the user's own key — disclose as "data sent to
      third party only when the user configures their own API key" in the privacy policy).
- [ ] Privacy policy URL (required) — host a German+English page mirroring `docs/privacy.md`.
- [ ] Screenshots (popover, Modi, Lokale Modelle, Onboarding) at required resolutions.
- [ ] German + English descriptions; price/free decision; review notes explaining
      Accessibility usage and the local llama.cpp helper.

## 4. Out of scope for automation (needs Jason)

- Apple account enrollment, certificate creation, App Store Connect setup, the actual
  `notarytool`/Transporter submissions, responding to App Review.
- Everything else (entitlements variants, build flags, signing scripts, metadata texts)
  is prepared in the repo and referenced above.
