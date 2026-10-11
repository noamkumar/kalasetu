# KalaSetu (Artisan AI)
## Complete Project Build Specification
*Bridging Artisans to the World*

- **Document purpose**: Single source of truth for an AI coding agent (Google Antigravity) to build the entire app from scratch.
- **Platforms**: Flutter mobile app (Android first) + responsive web/desktop dashboard; FastAPI backend.
- **Core AI features**:
  1) AI Image Enhancer and Studio
  2) Multilingual Auto-Cataloger
  3) Dynamic Pricing Assistant
- **Platform feature**: Full app localization in 6 languages: English, Hindi, Tamil, Telugu, Kannada, Malayalam.
- **Visual reference**: Linen and Olive design system (tokens in Section 5) and the attached UI mockup image.
- **How to use**: Read Section 0 first. Build one phase at a time (Section 16). Verify and commit after each phase.

---

## 0. Instructions for the AI Agent (read first)
You are a senior full-stack engineer (Flutter + Python). Build the project described in this document from an empty folder. Follow the phases in Section 16 strictly in order. Do not skip ahead. Do not invent features that are not in this document; ask instead.

### 0.1 Operating rules
- Work on one phase at a time. Start every phase by writing a short plan listing the files you will create or change.
- Keep business logic separate from UI (repositories, services, providers vs widgets).
- No hard-coded user-facing strings. Every string uses a translation key (Section 6). No hard-coded colours, font sizes or spacing. Use theme tokens (Section 5).
- AI providers sit behind interfaces (ImageEnhancer, SpeechToText, Translator, DescriptionGenerator, PriceEstimator, MarketData). Implement a Mock and a real version of each so the UI works without API keys.
- Never commit secrets. Read configuration from environment variables; commit only .env.example.
- After each phase run: flutter analyze, flutter test, pytest. Fix all errors. Then summarize what you built, what is untested, and how a human can verify it on an emulator.
- Use the simplest implementation that satisfies the acceptance criteria; leave clean extension points for upgrades.
- Create a git commit at the end of each phase with a clear message (for example: 'phase 1: localization and app shell').
- If a requirement is ambiguous or an external service is unavailable, choose a safe default, document it in docs/DECISIONS.md, and continue.

### 0.2 Definition of done for the whole project
- An artisan can: photograph a product, enhance it, speak a description in their language, receive six-language listings, receive a price suggestion, and publish - in under 3 minutes.
- Switching the app language instantly changes all UI text and all product text.
- Core flows work offline or queue gracefully and sync later.
- Layouts match the mockup on mobile (under 480 px wide), tablet and desktop (900 px and above).
- The AI never invents product facts; the suggested price is never below the cost floor.

---

## 1. Product Overview
KalaSetu is an offline-first, voice-first app that helps Indian artisans (potters, weavers, wood-craft makers, bamboo and jewellery makers) turn a phone photo and a spoken sentence into a professional e-commerce listing. Many users have low literacy, speak regional languages and have unreliable internet. Every decision must therefore favour large touch targets, voice input and output, icons over text, and working offline.

### 1.1 Feature summary
1. **AI Image Enhancer and Studio**: In-app camera with live lighting guidance. AI removes cluttered backgrounds, corrects lighting and white balance, centres the product, adds a soft shadow and exports marketplace-ready images.
2. **Multilingual Auto-Cataloger**: Artisan records a voice note in any supported language. AI transcribes it and generates a professional, SEO-friendly listing in English, Hindi, Tamil, Telugu, Kannada and Malayalam.
3. **Dynamic Pricing Assistant**: ML model plus market comparables and cost data suggests a competitive price (budget / recommended / premium) with a transparent breakdown and a spoken explanation.
4. **Full App Localization**: Entire UI and all product content switch between 6 languages at runtime without restart.
5. **Supporting features**: Auth (phone OTP), catalogue, product details, add-product wizard, orders, profile, KalaMitra voice/chat assistant, connectivity pill, offline sync queue, text-to-speech (Tap to hear), analytics and desktop dashboard.

### 1.2 Users
- **Artisan (primary)**: low-literacy, regional-language speaker, Android phone, patchy network, wants to sell without typing.
- **Customer (secondary)**: browses catalogue in their preferred language, views details, places an order.
- **Admin (optional, later)**: out of scope for v1.

---

## 2. Technology Stack and Architecture
- **Client**: Flutter 3.x (mobile, web, desktop from one codebase), Dart 3
- **State management**: Riverpod 2.x (`flutter_riverpod`), unidirectional data flow
- **Routing**: GoRouter 14.x with redirects for auth state and language selection
- **Local storage / offline**: Drift (SQLite) for structured data, Hive for settings and cache, WorkManager for background sync with exponential backoff
- **Localization**: easy_localization (JSON files per language) plus intl for number, currency and date formatting
- **Voice**: record (audio capture), flutter_tts (on-device speech), backend Speech-to-Text (Whisper or Google STT)
- **Camera / images**: camera, image_picker, image (on-device resize), cached_network_image
- **Backend**: Python 3.11, FastAPI, Pydantic v2, SQLAlchemy 2, Alembic; PostgreSQL in production, SQLite in development
- **Object storage**: S3-compatible bucket (or Firebase Storage) for original and enhanced images; local folder in development
- **Auth**: JWT access plus refresh tokens; phone number plus OTP (OTP provider behind an interface; console-print provider in dev)
- **AI - vision**: rembg (U2-Net / ISNet) for background removal; OpenCV and Pillow for lighting, white balance, crop, shadow
- **AI - language**: Gemini API (default) behind a provider interface for cleanup, translation, description generation and vision tagging
- **AI - pricing**: scikit-learn / LightGBM regression + comparables retrieval + LLM explanation layer
- **Background jobs**: FastAPI BackgroundTasks for MVP; Celery + Redis as scale-up path
- **Testing**: flutter_test, golden tests, mocktail; pytest, httpx; GitHub Actions optional

### 2.1 Architecture rules
- **Client**: feature-first modules. core/ (theme, routing, shared widgets, services, l10n), data/ (models, repositories, REST clients, local DB), features/ (self-contained domain packages).
- **Repository pattern**: UI reads from local Drift DB first via repositories; repositories refresh from network; writes go to a local sync queue.
- **Providers as interfaces**: each AI capability is an abstract class with Mock and Real implementations chosen by an environment flag (`AI_MODE=mock|real`).
- **Backend layers**: routers (HTTP only) -> services (business logic) -> providers (external AI) and db (persistence). Routers never call external APIs directly.

---

## 3. Repository Structure
```
kalasetu/
  AGENTS.md
  docs/ PROJECT_SPEC.md DECISIONS.md ui-mockup.png
  frontend/
    pubspec.yaml
    assets/translations/ en.json hi.json ta.json te.json kn.json ml.json
    assets/fonts/ (Fraunces, Manrope, Noto Sans Devanagari/Tamil/Telugu/Kannada/Malayalam)
    lib/
      main.dart app.dart
      core/
        theme/ app_colors.dart app_text_styles.dart app_spacing.dart app_radii.dart app_elevation.dart app_theme.dart
        routing/ app_router.dart route_names.dart
        widgets/ app_scaffold.dart app_header.dart app_button.dart artisan_card.dart
                 responsive_widgets.dart speaker_affordance.dart empty_craft_state.dart
                 craft_category_badge.dart kalamitra_fab.dart step_progress_bar.dart
                 connectivity_pill.dart language_picker.dart price_suggestion_card.dart
                 image_compare_slider.dart voice_recorder_button.dart motifs/
        services/ tts_service.dart connectivity_service.dart audio_service.dart
        l10n/ locale_controller.dart
      data/
        models/ repositories/ api/ local_db/ (drift tables, hive boxes) sync/
      features/
        auth/ onboarding/ home/ catalogue/ product_detail/ add_product/
        studio/ cataloger/ pricing/ orders/ profile/ kalamitra/ dashboard/ gallery/
    test/ integration_test/
  backend/
    requirements.txt .env.example alembic/
    app/
      main.py config.py deps.py
      routers/ auth.py products.py images.py catalog.py pricing.py orders.py
               translate.py sync.py assistant.py analytics.py
      services/ image_enhancer.py speech.py translator.py description_gen.py
                price_estimator.py market_data.py
      providers/ interfaces.py gemini_provider.py whisper_provider.py rembg_provider.py
                 mock_providers.py
      models/ schemas/ db/ utils/
    ml/ train_pricing.py dataset/seed_prices.csv artifacts/
    tests/
```

---

## 4. Visual Reference
The attached mockup image shows: the design-system palette and typography, UI components (buttons, input, card, chips, connectivity pill, speaker button, floating assistant, bottom nav, empty state), 7 mobile screens (Splash, Onboarding, Home/Catalogue, Product Details, Add Product, My Orders, Profile) and 3 desktop screens (Dashboard, Products Management, Analytics).

---

## 5. Design System: Soft Luxury Minimalist (Linen and Olive)

### 5.1 Colour tokens (`AppColors`)
- `background`: `#FAF6F0` (travertine off-white) - Scaffold background
- `surface`: `#FFFFFF` - Cards, sheets, inputs
- `hairline`: `#2B2E2A` at 8% opacity - 1 px borders
- `inkPrimary`: `#2B2E2A` (espresso charcoal) - Primary text
- `inkSecondary`: `#6A6E67` - Secondary text, hints
- `primary`: `#606C56` (sage); dark `#454E3E`; light `#E8ECE4` - Primary buttons, active tab, selected chips
- `secondary`: `#C7A379` (linen sand / ochre); light `#F6EFE6` - Secondary buttons, highlights
- `accentBlue`: `#4A6572` - KalaMitra assistant
- `status`:
  - Online green (`#2E7D32`), syncing amber (`#E65100`), offline grey (`#757575`), error red (`#C62828`)
  - Terracotta (`#C85A32`) and ochre (`#D9822B`) for craft/order states

### 5.2 Typography (`AppTextStyles`)
- Headings and display: Fraunces (variable serif), letter-spacing -0.02em.
- Body, UI, labels: Manrope weights 300, 400, 500, 700.
- Indic script fallbacks: Noto Sans Devanagari (Hindi), Noto Sans Tamil, Noto Sans Telugu, Noto Sans Kannada, Noto Sans Malayalam. Set line height >= 1.2.
- Responsive font scale: 0.88x (<480 px), 1.0x (480-899 px), 1.15x (>=900 px).

### 5.3 Shape, spacing and elevation
- 8 pt grid (`AppSpacing`).
- Radii (`AppRadii`): button 999 (capsule), card 28, input field 16.
- Card: white, 1 px hairline border, ambient shadow `rgba(43,46,42,0.03)` with blur 40.
- Minimum touch target 48 dp on every interactive element.

### 5.4 Responsive rules
- Under 480 px (mobile): Bottom navigation, 2-column product grid, buttons stack vertically when narrower than 480.
- 480 to 899 px (tablet): Bottom navigation or rail, 3-column grid.
- 900 px and above (desktop): Left sidebar navigation, 4-column grid, ResponsiveContainer max width 1200 with 48 px side padding, tables instead of lists.

### 5.5 Reusable components (Phase 0)
- `AppScaffold`: Page frame with subtle Warli watermark pattern, optional header, bottom nav or sidebar.
- `AppHeader`: Title, notification bell with unread badge, ConnectivityPill.
- `ConnectivityPill`: Capsule: Online (green), Syncing with count (amber), Offline (grey).
- `AppButton`: Variants primary, secondary, outlined, text; loading state; capsule shape; 48 dp min height.
- `ArtisanCard`: 28 px radius white card with ambient shadow; optional image, title, price, rating.
- `ResponsiveContainer` / `ResponsiveGridView`: Max width constraint; 2/3/4 column grid by breakpoint.
- `SpeakerAffordance`: Capsule or icon button labelled "Tap to hear"; calls TTS in current locale.
- `EmptyCraftState`: Line-art potter's wheel illustration, title, subtitle, action button.
- `CraftCategoryBadge`: Chip with craft icon (Pottery, Handloom, Jewelry, Wood Craft, Bamboo); selected state in sage.
- `KalaMitraFab`: Floating capsule with bot avatar and label, opens assistant sheet.
- `StepProgressBar`: Numbered steps joined by dashed Tanka-stitch lines.
- `LanguagePicker`: Large native-script buttons (Section 6); bottom sheet or full screen.
- `PriceSuggestionCard`: Big recommended price, budget/premium range, confidence, breakdown, comparables, speaker button.
- `ImageCompareSlider`: Before/after drag slider for enhanced photos.
- `VoiceRecorderButton`: Large mic button, live waveform, timer, hold or tap to record, 90 s limit.
- Debug route `/gallery`: renders every component in every variant.

---

## 6. Feature 4: Full App Localization (6 Languages)
Languages:
- English (`en` / `en-IN`): English
- Hindi (`hi` / `hi-IN`): हिन्दी
- Tamil (`ta` / `ta-IN`): தமிழ்
- Telugu (`te` / `te-IN`): తెలుగు
- Kannada (`kn` / `kn-IN`): ಕನ್ನಡ
- Malayalam (`ml` / `ml-IN`): മലയാളം

---

## 7. Build Phases (execute strictly in order)
- **Phase 0**: Foundations and design system
- **Phase 1**: Localization and app shell
- **Phase 2**: Auth, data layer, offline sync, catalogue
- **Phase 3**: AI Image Studio
- **Phase 4**: Multilingual Auto-Cataloger
- **Phase 5**: Dynamic Pricing Assistant
- **Phase 6**: Orders, assistant, desktop dashboard
- **Phase 7**: Hardening and release readiness
