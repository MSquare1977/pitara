# Phase 4 — Web + Backend Sync: Architecture

Status: **design agreed, not yet built**. This doc captures the decisions so implementation can start from a clear spec rather than being figured out mid-build.

## Backend: Firebase

- **Firebase Auth** — identity (Google now, Apple later — see below)
- **Firestore** — category/document/member metadata
- **Cloud Storage for Firebase** — encrypted file blobs
- No custom server needed beyond Firebase itself

## Encryption model (unchanged in spirit from the local-only version)

- The AES-256 master key is still generated on-device and still never leaves a device in plain form
- To let a second device (the web app) access the same key: the key is **wrapped** (encrypted) using a key derived from a **sync passphrase** — separate from the Google/Apple login, never transmitted or stored in plain form
- The wrapped key blob lives in Firestore (replacing the earlier "Drive appDataFolder" idea) — small, opaque, meaningless without the passphrase
- **No recovery if the sync passphrase is forgotten** — existing signed-in devices keep working; adding a *new* device without the passphrase isn't possible. (Per your call — matches how Bitwarden/1Password master passwords work.)
- Document files themselves are encrypted client-side before upload — Firebase/Google never sees plaintext

## Sync scope — what's authoritative where

- **Web app is lightweight** (per your call): sign in, pick a category, upload a document. It does not create/edit/delete categories or manage people.
- **Categories and people remain app-authoritative** — created/edited/deleted only in the Android (later iOS) app — but both still **sync to Firestore** so the web app can read the current list and let the user pick one when uploading. Web is read-only on these.
- **Documents sync both ways** — a document added via the app appears in Firestore/Storage; a document uploaded via web appears next time the app syncs. Both clients write to the same backend, so this is automatic once both are wired up, not a special case.
- Conflict handling: last-write-wins per record using an `updatedAt` timestamp (new field needed on `VaultDocument`/`DocCategory`, not present today) — reasonable for personal documents that aren't concurrently edited by multiple people at once.

## Auth: moving from bare `google_sign_in` to Firebase Auth

Phase 3 today calls `google_sign_in` directly. For Phase 4, this needs to route through **Firebase Auth** instead (Google Sign-In becomes one *provider* under Firebase Auth, not the whole auth system):
- Lets Firestore security rules check `request.auth.uid` directly
- Makes adding Apple Sign-In later a matter of adding a second provider to the same Firebase Auth user, not building a parallel auth system
- Firebase Auth supports **account linking** — same person could sign in with either Google or Apple and land on the same account/data

This is an adjustment to Phase 3's existing code, not a throwaway — the UI and `AuthProvider` shape stay similar, the underlying call changes.

## iOS — groundwork this phase makes easier

Flutter + Firebase (FlutterFire) both run on iOS with the same codebase — this is not a rewrite. See chat answer below for specifics and real constraints (a Mac is required to build/test iOS regardless of code).

## Free vs. Paid tiers

- **Free**: local-only, device storage, exactly what exists today. No account required.
- **Paid (Pitara Cloud)**: cloud sync via this Firebase architecture, web access, family sharing. Requires sign-in.
- Choice offered on first app launch, and changeable anytime via the hamburger menu ("Upgrade to Pitara Cloud" / "Manage subscription").
- **Free → Paid**: triggers the sync-passphrase setup, then uploads the existing local vault to Firebase. Needs a visible progress UI for larger vaults.
- **Paid → Free (cancellation)**: cloud data is kept for a **30-day grace period** after lapse — re-subscribing within that window restores full access with no data loss. After 30 days, the user is prompted to export before permanent deletion. Cloud data is not deleted immediately on cancellation.

## Payment

- **Phase A (build first)**: Stripe, web-only. Mobile app has no in-app purchase UI at all — tapping "Upgrade" in the app opens the **system browser** (not an embedded webview, to stay unambiguously outside app-store in-app-purchase policy) to the Pitara web app, where the same Firebase Auth session carries over, Stripe checkout happens, and the web app gates all vault UI behind a confirmed-subscription check in Firestore. The **mobile app** (not web) performs the actual local-vault-to-cloud upload once it detects the account is now subscribed, since mobile holds the real documents.
- **Phase B (later)**: native in-app purchase (Google Play Billing, later Apple IAP) as an additional path to the same "subscribed" account state — not a redesign, an alternative entry point.
- ⚠️ Before implementing Phase A: verify current Google Play / Apple policy on linking out to external payment from within an app — this is an actively shifting regulatory area and should be checked fresh at build time, not assumed from today's understanding.

## Family sharing — architecture addition

Sharing requires a genuinely separate piece of cryptography beyond the core sync design above, because each user's document key is wrapped with *their own* passphrase — a recipient can't decrypt with a key they don't have.

- Each cloud user gets a **public/private keypair** (generated on first cloud enrollment)
- Sharing a folder generates a **new key just for that folder**, which gets encrypted once per recipient using *their* public key, and stored (still encrypted) in Firestore
- Only someone holding the matching private key — i.e., someone actually granted access — can unwrap the shared-folder key
- This is the same pattern used by properly zero-knowledge sharing tools (not an improvised shortcut)
- **Scope as its own build phase**, after core Firebase sync is working and verified — not bundled into the first cloud release
- Sharing limit: starts at 1 person, app-level constant, raisable to 5 — and a natural **pricing tier lever** (see below)

### Mutual delete confirmation
- A shared document gets a `deletionMarkedBy` list (set of user IDs)
- Either party marking delete adds themselves to the list; UI shows "pending deletion — confirm or undo" to all parties with access
- Document is only actually purged once *everyone* with access has marked it
- Either person can undo *anyone's* mark, not just their own
- Fits naturally on Firestore's real-time listeners — state updates live for all parties

## Multi-factor authentication

- **TOTP (authenticator app) only** — no SMS, to avoid per-message cost and because TOTP is free (likely via Firebase's "Identity Platform" upgrade mode — confirm exact setup requirement at build time; either way, well within the free MAU tier at Pitara's current scale)
- **Applies at two moments**: (1) accepting a shared-folder invite, (2) general cloud account login — confirm exact scope when building
- **User can turn it off**, but must acknowledge an explicit in-app warning about the risk before doing so — not a silent toggle

## Honest security framing

- Never claim "hacker-proof" anywhere in the product or marketing — no real system can make that claim, and even established players (e.g. a 2026 incident where a competitor's encrypted vaults were stolen via brute-force, though attacker-side ciphertext stayed unreadable) show breaches happen regardless of encryption quality
- Accurate claim to use instead: **"even if our servers are breached, your documents stay unreadable without your passphrase"** — true, strong, and not a liability if something ever does go wrong
- A professional **security audit becomes necessary, not optional**, once real paying customers are involved — this was flagged in the original pitch deck as what funding unlocks; Phase 4 cloud launch is the point where it stops being deferrable

## Pricing — grounded in competitor research (Oct 2026)

Comparable zero-knowledge vault apps (password managers, closest market comparison):
- 1Password Individual: ~$3.99/mo billed annually ($47.88/yr), ~$4.99/mo billed monthly
- Dashlane Premium: ~$4.99/mo (annual-only billing)
- Family/shared plans generally run $7–8/mo for up to 5–10 seats

**Important: Firebase infrastructure cost itself is not the pricing driver.** Estimated raw cost per user (storage + bandwidth for a typical personal-document vault) is a fraction of a cent to a few cents per month — a rounding error. Real costs worth pricing for are development time, customer support, and payment processing fees (Stripe ~2.9% + 30¢ per transaction), not Firebase line items.

**Suggested starting point** (revisit once real usage data exists):
- Individual cloud plan: **$3.99/mo** or **$39.99/yr** (≈$3.33/mo, standard annual discount pattern) — competitive with 1Password/Dashlane individual tiers
- Family/sharing tier (up to 5 people): **$6.99/mo** or **$69.99/yr**
- This is a reasoned starting estimate, not a guarantee — should be sanity-checked against your own support-cost and growth assumptions, which aren't knowable from here

## Open items for before/during implementation

- [ ] Add `updatedAt` to `VaultDocument` and `DocCategory`
- [ ] Decide Firestore data shape (one document per category/document/member, security rules scoped to `request.auth.uid`)
- [ ] Decide passphrase-set UX: when is the user first asked to set one? (Likely: first time they try to enable web access)
- [ ] Migrate Phase 3 auth from bare `google_sign_in` to `firebase_auth` + Google provider
- [ ] Design the minimal web upload flow (sign in → pick category → pick person (optional) → pick file → done)
- [ ] Build first-launch Free/Paid chooser + drawer entry for upgrading/managing subscription
- [ ] Build Stripe web checkout, gated behind Firestore subscription-status check
- [ ] Build system-browser handoff from mobile app (not embedded webview)
- [ ] Build the 30-day grace-period + export-before-delete flow for cancellations
- [ ] Verify current Play Store/App Store external-payment-link policy before shipping the payment handoff
- [ ] Confirm Firebase TOTP MFA setup requirement (Identity Platform upgrade or not) and enable accordingly
- [ ] Scope and build family sharing (public/private keypairs, per-folder keys) as its own phase, after core sync ships
- [ ] Build mutual-delete-confirmation UI and `deletionMarkedBy` data model for shared documents
- [ ] Legal/compliance pass before charging money: terms of service, privacy policy, refund policy — not yet drafted