# KalaSetu — Artisan Usability & Accessibility Checklist

This document details the usability guidelines, accessibility standards, and field-testing checklist designed for non-literate, non-technical Indian artisans, weavers, and micro-entrepreneurs using entry-level Android smartphones.

---

## 1. Core Ergonomic & Interface Principles

| Requirement | Target Standard | Implementation in KalaSetu |
|---|---|---|
| **Touch Targets** | Min 56–64 dp height & width | Primary buttons (`Publish Now`, `Yes, This is Good`, `Fast Add`, `Call Buyer`) are 56–64 dp with rounded corners. |
| **Viewport Range** | 320 px to 412 px (entry Android) | Mobile-first layouts using flexible rows, scroll views, and scalable units without overflow. |
| **Text Scale** | Supports `TextScaler.linear(1.3)` | Dynamic typography system verified at 1.30 text scaling with zero `RenderFlex` overflows. |
| **Color Contrast** | WCAG 2.1 AAA (>= 7:1) | Deep indigo (`#1A237E`), terracotta (`#C84B31`), and ochre (`#D97706`) against clean paper surface (`#FFFDF9`). |
| **One Task / Screen** | Single focal action | Each screen guides one specific milestone with a single dominant primary action button. |

---

## 2. Audio-First & Zero-Reading Architecture

1. **Automatic Spoken Narration**:
   - Every artisan screen speaks its primary instruction automatically in the artisan's chosen language (`en`, `hi`, `ta`, `te`, `kn`, `ml`, `bn`).
   - Powered by cached offline regional TTS audio bundles (`SimpleModeVoiceHelper`) with graceful speech fallbacks.
   - An auto-speak toggle is accessible in Profile Settings and Onboarding.

2. **Persistent Speaker Replay Button**:
   - A gold speaker icon (`Icons.volume_up_rounded`) is prominently anchored on every guided screen header.
   - Tapping replays the localized guidance aloud at any time.

3. **Global Voice Mic Routing**:
   - Header mic button triggers `GlobalVoiceCommandSheet`.
   - Captures speech and routes intents to `/assistant/chat` via Gemini (supporting commands like *"Add product"*, *"My orders"*, *"My earnings"*, *"Fair mode"*, *"Help me"*).

4. **Audio & Haptic Confirmations**:
   - Every completed action provides immediate sensory feedback: haptic vibration pulse + friendly spoken confirmation (*"Photo enhanced and ready"*, *"Your product card is ready"*, *"Order accepted"*).

---

## 3. The 5-Step "Sell a Product" Flow

```
[ Step 1: Photo ]  ──>  [ Step 2: Speak ]  ──>  [ Step 3: Check ]  ──>  [ Step 4: Price ]  ──>  [ Step 5: Publish ]
 (Take Photo /           (Hold Mic & Speak       (One-Tap Accept /        (AI Suggested            (One-Tap Publish,
  Gallery Upload,         in Mother Tongue)        Voice Change)            Fair Wage)               Instant Live)
  Auto-Enhanced)
```

- **Auto-Advance**: Steps advance automatically upon completion without requiring manual screen transitions.
- **One-Tap Accept / Voice Change**:
  - Green Checkmark (`Yes, This is Good`) advances instantly.
  - Mic Button (`No, Change It`) allows artisans to speak corrections in any language (*"Change color to crimson red"*).
- **Jargon Elimination**:
  - Replaced technical words like "SEO", "sync", "AI generation", "metadata" with plain terms (*"Your product card is ready"*, *"Your product is now in the shop"*).

---

## 4. Friendly Error Handling

- **Zero Technical Strings**: Stack traces, HTTP error codes, and backend errors are completely shielded from artisans.
- **Visual Empathy Dialogs**:
  - Illustrated with friendly contextual iconography (`Icons.wifi_off_rounded`, `Icons.camera_alt_rounded`).
  - Single clear spoken message: *"Do not worry. Please check your connection and tap Try Again."*
  - Single primary recovery button: **Try Again** (`58 dp`).

---

## 5. Specialized Modes

### A. Year-Round Selling (`/product/published-success`)
- Post-publish screen confirms: *"Your product is now in the shop for everyone to see!"*
- One-tap WhatsApp share with pre-formatted bilingual product card and image.
- High-contrast printable Stall QR code for physical exhibitions.

### B. Fair & Exhibition Mode (`/fair-mode`)
- Accessible via one-tap "I am at a fair" button from the main catalogue.
- Fast 2-tap camera product capture.
- 100% offline persistence using local Drift database.
- Whole-shop QR code displaying the artisan's complete exhibition stall inventory.

### C. Business Orders Inbox (`/orders/business`)
- Dedicated inbox for B2B bulk inquiries from retailers, emporiums, and corporate buyers.
- Spoken audio readout of buyer inquiries, unit quantities, and total offered value.
- Clear 3-way decision buttons: **Accept** (green), **Call Back** (blue), and **Not Now** (neutral).

### D. Honest Marketplace Connection (`/marketplaces`)
- Placed behind the extensible `MarketplaceAdapter` interface (`GeMMarketplaceAdapter`, `ONDCMarketplaceAdapter`).
- Honestly displays "Coming Soon" for live automated API synchronizations.
- Generates a ready-to-submit bilingual catalog export package (English & Hindi) that artisans or NGO coordinators can copy with one tap.

### E. My Earnings (`/earnings`)
- High-contrast typography displaying:
  - This Month's Earnings (₹)
  - Total Lifetime Earnings (₹)
  - Orders Fulfilled
- Audio narration reads out earnings and reinforces the Fair Wage Guarantee: *"Every rupee earned goes 100% directly to you. Zero middleman commission."*

### F. Assisted Mode (NGO & Cluster Helpers)
- Dedicated registration pathway for cluster helpers and NGO workers onboarding artisans.
- Records helper name and agency code on the session.
- Seamless one-tap **"Handover Account to Artisan"** mechanism in Profile Settings with spoken confirmation.

---

## 6. Field Usability Verification Checklist

Before deploying updates or field testing with artisans, verify the following:

- [x] **Touch Target Size**: All touchable elements measure $\ge 48 \times 48\text{ dp}$; primary buttons measure $56\text{ to }64\text{ dp}$.
- [x] **No Typing Required**: Phone numbers use the `BigNumericKeypad`; locations are picked from visual craft clusters or voice; descriptions are captured via speech.
- [x] **1.3x Text Scale**: Verified on low-density 360 dp screens with `TextScaler.linear(1.3)`. No text clipping or overflow boxes (`A RenderFlex overflowed...`).
- [x] **Speaker Buttons Visible**: Replay speaker button is visible on every screen header.
- [x] **Offline Resilience**: Fair mode creates products and generates stall QR codes when device is completely offline.
- [x] **Multi-Language Parity**: All 6 official scheduled languages (`en`, `hi`, `ta`, `te`, `kn`, `ml`) have 100% key parity with identical translation schemas.
- [x] **Spoken Error Feedback**: Friendly picture dialogs show only "Try Again" without raw stack traces.
