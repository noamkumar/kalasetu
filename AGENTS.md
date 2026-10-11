# KalaSetu - Agent Rules
Spec: docs/PROJECT_SPEC.md. Visual reference: docs/ui-mockup.png.
- Work on ONE phase at a time (spec Section 16). Plan first, then code.
- Stack: Flutter + Riverpod + GoRouter + Drift/Hive (frontend/), FastAPI (backend/).
- No hard-coded strings or colours: use translation keys and theme tokens.
- AI providers behind interfaces with Mock and Real implementations (AI_MODE env).
- Never commit secrets; use environment variables.
- After each phase run flutter analyze, flutter test, pytest; summarize results.
- Do not add features outside the spec; ask first. Log assumptions in docs/DECISIONS.md.
