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

## Category locks (per-category password)

A user can lock an individual category (e.g. "Finance", "Will & legal") behind its own password. Built in two layers, in this order.

**Layer 1 — local gate (build first, before Firebase).** Full spec and proposed defaults are in `FEATURE_BACKLOG.md`. It is a gate inside an already-unlocked app, not encryption: the lock hides the category, and attached files stay protected by the existing device vault key. Titles, categories and expiry dates are still stored as plain text on the device.

**Layer 2 — real encryption (this phase).** Once cloud sync exists, a gate is not enough, because the web app and other devices would not enforce it.

- Each locked category gets its own random **category key** — the same pattern as the per-folder keys designed for family sharing. Files in that category are encrypted with the category key, not the vault master key.
- The category key is stored **wrapped twice**: (a) by a key derived from the category password (slow hash + salt), and (b) by the device-held key, which powers the reset path on that device.
- The wrapped category-key blobs sync via Firestore, so the lock follows the user to the web app and other devices. Locked files stay unreadable, even to the app, until the category is unlocked; the category relocks when the app is backgrounded or after a timeout.
- **Real password required.** A 4-digit PIN is too easy to brute-force once encryption depends on it, so enabling cloud sync prompts the user to upgrade a weak category PIN to a proper password or passphrase.
- **Reset ("forgot password")**: proof of identity on a device that holds the device key — **fingerprint/face only**, not the device PIN, so someone who merely knows the phone's PIN cannot reset the lock. Device authentication is also what opens the app, so this is a convenience path, not a second independent factor. A **TOTP authenticator code** later becomes the proof step (or is added to it), and is also what makes reset possible from the web app, which has no device key.
- **No device, no biometric reset, no password = unrecoverable** for that category's files, consistent with the no-recovery stance on the sync passphrase. Setting a lock must show this warning.
- **Sharing**: a locked category must be unlocked before it can be shared. Recipients get the separate per-share key, never the category password.
- Coverage rules from Layer 1 (search, alerts, backup, share/export) apply here too.

## Honest security framing

- Never claim "hacker-proof" anywhere in the product or marketing — no real system can make that claim, and even established players (e.g. a 2026 incident where a competitor's encrypted vaults were stolen via brute-force, though attacker-side ciphertext stayed unreadable) show breaches happen regardless of encryption quality
- Accurate claim to use instead: **"even if our servers are breached, your documents stay unreadable without your passphrase"** — true, strong, and not a liability if something ever does go wrong
- A professional **security audit becomes necessary, not optional**, once real paying customers are involved — this was flagged in the original pitch deck as what funding unlocks; Phase 4 cloud launch is the point where it stops being deferrable

## Pricing and unit economics (corrected Oct 2026)

> **Correction.** An earlier version of this section called infrastructure cost "a rounding error". That assumed roughly 100 MB per user. At the 20 GB per user scenario below, infrastructure is about **$0.60 per user per month** on Firebase — small next to people costs, but not negligible, and **download charges can exceed storage charges**. The editable model is `Pitara_cost_model.xlsx`; the numbers here are its defaults.

**Basis:** 100 / 500 / 1,000 *paying* cloud users, 20 GB stored each, 1 GB downloaded per user per month, USD. Free local-only users store nothing on our servers and cost almost nothing. 20 GB is a stress case — a vault of scans and PDFs is usually far smaller; at 3 GB per user, infrastructure at 1,000 users falls to about $0.15 per user.

### Monthly cost at launch pricing ($4.99/mo or $49.99/yr, 70% annual, Firebase storage)

| | 100 users | 500 | 1,000 |
|---|---|---|---|
| Infrastructure (storage + downloads + other) | $62 | $300 | $610 |
| Card fees (Stripe) | $23 | $117 | $234 |
| Tooling (email, monitoring, helpdesk, domain) | $30 | $60 | $100 |
| Accounting, legal upkeep, insurance (rough) | $150 | $200 | $300 |
| **Cash cost, no salary for you** | **$265** | **$677** | **$1,244** |
| Maintenance (10 / 20 / 30 hrs at $50) | $500 | $1,000 | $1,500 |
| Support (10% of users, 20 min each, $25/hr) | $83 | $417 | $833 |
| **Full cost** | **$849** | **$2,094** | **$3,578** |
| Full cost per user | $8.49 | $4.19 | $3.58 |
| **Profit if you do maintenance and support yourself** | **+$176** | **+$1,529** | **+$3,169** |
| **Profit if you pay for them** | **−$407** | **+$113** | **+$835** |
| Break-even monthly price, paying staff | $9.75 | $4.73 | $4.01 |

### What this means

- **People costs, not infrastructure, decide profitability.** At 100 users, full cost per user is $8.49 against about $0.62 of infrastructure. Below a few hundred users this works only if the founder does maintenance and support.
- **Downloads are a design constraint.** Downloading a full 20 GB vault costs about $2.40 on Google's network. A new device must never pull the whole vault: **download on demand, per file, when opened.** If every user re-downloaded their whole vault monthly, downloads alone would cost about $230 / $1,110 / $1,910 per month at the three sizes.
- **The storage backend is swappable.** Files are encrypted before upload, so any backend only stores opaque blobs. Cloudflare R2 ($0.015/GB, free downloads) or Backblaze B2 ($0.00695/GB, free downloads up to 3x stored data) cut infrastructure from about $0.61 to $0.33 and $0.17 per user per month. **Start on Firebase Storage (fastest to build) but keep storage behind a single interface** so it can move later; moving means building signed-URL upload/download via Cloud Functions.
- **Don't compete on gigabytes.** Market comparables (Oct 2026): Proton Drive 200 GB at $3.99/mo billed annually, Sync.com 150 GB at $3.50/mo annually, iCloud+ and Google One 200 GB at $2.99/mo; password managers sit around $4–5/mo. Pitara sells the organised vault, expiry alerts, family sharing and the India–UK focus, with a storage cap.

### Recommended starting prices (revisit with real data)

- **Free:** local-only, as today.
- **Individual:** 20 GB included, **$4.99/mo or $49.99/yr**.
- **Family:** up to 5 people, 100 GB shared, **$7.99/mo or $79.99/yr**. Not modelled in detail; roughly $4.50/mo is left after storage and card fees even if the 100 GB were completely full.
- **Push annual billing.** Card fees are roughly 8–10% of a small monthly charge but under 4% of an annual one. Skip a semi-annual plan at launch.
- **A free trial is affordable:** a trial user with a full 20 GB vault costs about $0.60 for the month.
- These supersede the earlier suggestion of $3.99/$39.99 and $6.99/$69.99.

### Assumptions and exclusions

- **Verified (Oct 2026):** Google Cloud Storage price and tiered download charges, Cloudflare R2, Backblaze B2, Stripe UK card fees, competitor prices. Stripe Billing fee sources disagree (0.25% vs 0.7%); the model uses 0.7%.
- **My assumptions:** 20 GB per user, 1 GB downloads, other infrastructure, tooling, accounting/legal, maintenance hours, hourly rates, support rate, 70% annual mix, all users paying.
- **Not included:** VAT/GST (UK, EU and India can each require registration, sometimes with no minimum turnover — needs a tax adviser before launch); security audit; legal documents; Apple Developer fee ($99/yr once iOS exists); card dispute fees and refunds; marketing and acquisition costs.

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
- [ ] Put file storage behind a single interface (upload / download / delete) so the backend can move from Firebase Storage to R2 or B2 later
- [ ] Enforce the on-demand download rule: never sync an entire vault to a new device
- [ ] Decide whether to encrypt document metadata (titles, categories, expiry dates) — today it is plain text on the device
- [ ] Switch the cloud file format from AES-CBC to authenticated encryption (AES-GCM) before any cloud data is written; verify a package that supports it on both mobile and web
- [ ] Category locks: build Layer 1 first (see `FEATURE_BACKLOG.md`), then Layer 2 (per-category keys, wrapped twice, synced via Firestore)
- [ ] Get a tax adviser's view on VAT/GST registration before charging customers
- [ ] Get quotes for a security audit, legal documents and accounting before launch