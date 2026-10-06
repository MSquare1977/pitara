# Pitara — feature backlog

Living list of what's built, what's next, and what's further out. Add to this as priorities shift.

## ✅ Done

- Category grid home screen, 2×3 layout, brass accent theme, light/dark toggle
- Add / rename / delete / reorder categories, with a warning before deleting one that still has documents
- Add / edit / delete documents within a category, generic form reused everywhere
- Local keyword search across titles, categories, and status ("renew", "expiring")
- Lock screen using the device's own Face ID / fingerprint / PIN (`local_auth`)
- Real file attachment: camera photo, gallery photo, or PDF
- AES-256 encryption of attached files, key held in Android Keystore (`flutter_secure_storage`)
- Decrypt-on-view for both images and PDFs (pinch-zoom PDF viewer)
- Data persistence across app restarts (`shared_preferences` for categories/documents, encrypted files on local disk)

## ✅ Done (continued)

- [x] Share and Export buttons on the document detail screen — decrypt-and-share via the Android share sheet
- [x] Full vault backup — zips every document's decrypted file + a manifest, shared out via the OS share sheet
- [x] Uninstall / key-loss risk addressed — backup flow above gives a way out, plus a dismissible reminder banner on the home screen if a backup has never been made
- [x] `FLAG_SECURE` — vault content hidden from the Android recent-apps preview and blocked from screenshots
- [x] Custom app icon — brass padlock on navy, generated and applied via `flutter_launcher_icons`

## ✅ Done (continued)

- [x] Splash screen — brass padlock + Pitara wordmark on navy, via `flutter_native_splash`
- [x] More file types beyond image/PDF — general file picker, opens externally via `open_filex` for types we can't preview inline
- [x] Total storage size shown on home screen (KB/MB/GB)
- [x] Signed release APK, installable outside the dev setup
- [x] Family/shared vault (local) — tag documents by person, manage people from the drawer
- [x] Responsive category grid — column count adapts to screen width instead of being fixed at 2
- [x] Time-aware greeting (was hardcoded to "Good evening")
- [x] Share vs Export now genuinely distinct (share sheet vs native save dialog)
- [x] Notification bell for expiring documents (header + drawer), showing the full list, not just one

## ✅ Done (continued)

- [x] Phase 3 — Google Sign-In, confirmed working end-to-end on device

## 🔜 Next up

- [ ] **Phase 4 — Web version + Firebase backend** — architecture agreed, not yet built. Full design in `PHASE4_ARCHITECTURE.md`: Firebase (Auth + Firestore + Cloud Storage) as the backend, client-side encryption with a passphrase-wrapped key (no recovery), web app is upload-only (categories/people stay app-authoritative), auth migrates from bare `google_sign_in` to `firebase_auth` as groundwork for adding Apple Sign-In later

## 🧭 Later / bigger pieces

- [ ] Multiple files per document (e.g. front + back of a card)
- [ ] More file types beyond image/PDF
- [ ] Real conversational AI search (natural-language queries via an API, vs. today's local keyword matching)
- [ ] Cloud sync (zero-knowledge, multi-device) — the big one, needs the security audit conversation we discussed for the pitch
- [ ] Signed, release-mode build installable outside your dev setup
- [ ] Family/shared vault support (mentioned as a "later" idea during early research)

## 💡 Parked ideas (not committed, revisit if relevant)

- Smart expiry reminders as actual device notifications, not just the in-app banner
- Document categories with country tagging (India vs UK) if usage shows that's a real pain point