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
- [x] Package renamed from `com.example.pitara` to `com.msquare.pitara` (before Firebase registration, so it is only registered once)
- [x] Code under Git version control in a private GitHub repo; signing keystore and `key.properties` excluded
- [x] Premium restyle — navy and brass hero card, bold gradient category tiles, serif headings, navy lock screen, all via a central `AppTheme`
- [x] Header shows "{First name}'s Vault" with a shield icon once signed in; "Your Vault" when signed out
- [x] Smarter title search — matches word by word in any order, ignores capitals and accents, tolerates small typos, ranks title matches first; still searches labels only (title, subtitle, category, person), not file contents. Unit tests in `test/document_search_test.dart`
- [x] **Checklist / planner (automatic)** — built, **awaiting a test on your device**. One table (Document, Folder, Status, optional due date) listing every vault document automatically as "Added", plus placeholder rows for documents you still need. Placeholders can be filled by adding the document from the row or by linking one already in the vault; deleting an attached document sends its row back to "To add"; a deleted folder shows "No folder". Filters All / To add / Added, a progress line, "Overdue" for past due dates, and the checklist is listed in the backup manifest. Opened from the drawer. Logic tests in `test/checklist_rows_test.dart`

## 🔜 Next up

- [ ] **Decisions pending** — 20 open questions (storage model, launch order, pricing, billing entity, encryption format, Drive access model, web scope, category-lock defaults, Play account type and more) are recorded in `PHASE4_ARCHITECTURE.md` under "Open questions — awaiting your decision", each with a recommended default. Nothing there is decided yet.
- [ ] **Category locks — Layer 1 (local gate)** — buildable now, independent of Firebase. *Proposed defaults, to confirm before building:*
  - Set, change or remove a password from the category's edit screen
  - Store only a **salted slow hash** (never the password) in secure storage, not the plain settings file; package to be chosen and verified at build time
  - Locked tiles show a lock icon; tapping one asks for the password; wrong attempts add growing delays
  - **Relock** every time the app goes to the background
  - Password minimum: 4 characters
  - **"Forgot password" = reset, not retrieval** (the app can never show the old password): prove identity with **fingerprint/face only** (`local_auth` biometric-only), then set a new password. If no biometrics are enrolled, fall back to the device PIN with a clear warning. Later: a TOTP authenticator code becomes the proof step (or is added to it)
  - **Coverage — a lock that leaks is worse than none:** search excludes locked categories; the bell shows only a count ("2 documents in locked categories need attention"), no titles; backup asks to unlock first or skips locked categories with a note; share/export require the category unlocked
  - **Honest limitation:** this is a gate, not encryption. Titles and dates remain plain text on the device, and anyone who can pass device biometrics could reset the lock. Layer 2 (real per-category encryption) is in `PHASE4_ARCHITECTURE.md` under "Category locks"

- [ ] **Colour themes with a profession icon** — a choice of palettes plus a small in-app badge: Standard (today's navy and brass), Medicine, Law, Students, Freelancers, Family and home, Expat and travel (later: Business owner, Property). Keep the shield next to "Vault" so the security message never changes. Effort: a few days for the theme system, then an hour or two per extra theme; the work is replacing hard-coded navy/brass on the home header, lock screen and drawer with theme colours, and checking light and dark contrast for every palette. **Wording caution:** Medicine and Law must read as "your own professional documents (licences, certificates, insurance)", never patient or client records, to stay clear of confidentiality and health-data rules. No per-theme launcher icon
- [ ] **Phase 4 — Web version + Firebase backend + Free/Paid tiers** — architecture and business model agreed, not yet built. Full design in `PHASE4_ARCHITECTURE.md`: Firebase (Auth + Firestore + Cloud Storage) backend, hosted web app on Firebase Hosting, passphrase-wrapped key encryption (with an optional printable recovery code), free local-only tier vs paid cloud tier, Stripe web-only payment to start, family sharing with per-folder public-key encryption + mutual-delete confirmation (later sub-phase), TOTP-only MFA, per-category locks (Layer 2), auth migrating from bare `google_sign_in` to `firebase_auth`. **Pricing corrected** — at 20 GB per user infrastructure is about $0.60/user/month and downloads can exceed storage; recommended launch pricing is $4.99/mo or $49.99/yr (Individual) and $7.99/mo or $79.99/yr (Family). Play with the numbers in `Pitara_cost_model.xlsx`. Blocked on the billing-account decision (personal card vs company) for Storage and Stripe/Cloud Functions; Firebase project, Auth, Firestore and Hosting can proceed without it.

## 🧭 Later / bigger pieces

- [ ] **Starter checklists and kits** — suggested lists such as "Moving to the UK" or "Starting university" that add placeholder rows (and optionally folders) to the checklist; a kit only ever adds, never deletes. Labelled "suggestions, not advice". The effort is writing accurate lists. Fits a future first-launch chooser alongside themes
- [ ] **Checklist and category locks** — when per-category passwords arrive, rows in a locked category must show as "Locked item" until unlocked, or the checklist would reveal which documents exist
- [ ] **Search inside documents** — find words that are only in the file (a policy number, an address, a clause). Today nothing inside a scan or PDF is read, because files are encrypted and the app extracts no text. Needs: (1) text extraction — read the text layer of PDFs directly, run OCR on photos and scans on the device; (2) a local search index of those words, **encrypted with the same keys as the files** (it is derived data and just as sensitive), rebuilt on each device rather than synced; (3) locked categories excluded from results until unlocked. Everything runs on the device, so "Pitara cannot read your documents" stays true. Show where in the document each match was found. Honest limits: OCR is poor on blurry photos, the index takes storage, and the first indexing run costs battery. **Depends on** the encryption decisions Q10 and Q11 and on category locks. It is also the groundwork for any later AI assistant, where the on-device versus hosted choice is still open
- [ ] **Candidate: "Login details" card type** — site, username, password and notes for the portals people keep alongside their documents (UKVI, HMRC, OCI, NRE bank accounts), with copy buttons that auto-clear. Pitched as "keep account details with the documents they belong to", not as a password manager. Small effort (days, my estimate). **Build only after** the encryption decisions Q10 (AES-GCM) and Q11 (metadata encryption) in `PHASE4_ARCHITECTURE.md`, because password fields must not sit in plain text
- [ ] **Candidate: "Family health records" template** — vaccination certificates, prescriptions, insurance and check-up reminders. Documents with dates, so it reuses the existing expiry-alert machinery and suits multi-country families
- [ ] Multiple files per document (e.g. front + back of a card)
- [ ] Real conversational AI search (natural-language queries via an API, vs. today's local keyword matching)
- [ ] Cloud sync (zero-knowledge, multi-device) — this is Phase 4 above; needs a professional security audit before charging customers
- [ ] Family sharing across devices (cloud) — the local "tag documents by person" version is done; real sharing is in `PHASE4_ARCHITECTURE.md`

## 💡 Parked ideas (not committed, revisit if relevant)

- **Full password manager (parked, with reasons)** — a real one needs system autofill (native Android code that Flutter does not cover) and browser extensions, plus breach checks, imports and passkeys: months of work and a permanent security burden, in a crowded market with strong free options (Google, Apple, Bitwarden). A stolen password is usable immediately, so the security bar is higher than for documents. Revisit only if users ask for it
- **Menstrual-cycle tracker inside Pitara (parked, with reasons)** — easy to build but a poor fit: it needs a daily habit and a different audience, and the market is crowded (Flo, Clue, Apple Health). Health data is special-category data under UK/EU data-protection law, and the Flo case shows the legal and reputational exposure when it is shared with third parties. If ever built, it would be a separate local-only product with no third-party analytics or ad code, explicit consent, and no fertility or contraception claims (a regulatory adviser should confirm where the medical-device line sits)
- Smart expiry reminders as actual device notifications, not just the in-app banner
- Document categories with country tagging (India vs UK) if usage shows that's a real pain point