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

## Open items for before/during implementation

- [ ] Add `updatedAt` to `VaultDocument` and `DocCategory`
- [ ] Decide Firestore data shape (one document per category/document/member, security rules scoped to `request.auth.uid`)
- [ ] Decide passphrase-set UX: when is the user first asked to set one? (Likely: first time they try to enable web access)
- [ ] Migrate Phase 3 auth from bare `google_sign_in` to `firebase_auth` + Google provider
- [ ] Design the minimal web upload flow (sign in → pick category → pick person (optional) → pick file → done)