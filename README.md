# 📺 Telly — The Beli for Movies, TV & Anime

> **"Your personal screen rankings. Ranked, shared, settled."**

**Telly** is a modern, social screen entertainment ranking and discovery mobile application designed to bring the viral, pairwise ranking mechanics of **Beli** to movies, television series, and anime.

By eliminating arbitrary, inflated 1–10 star ratings in favor of **head-to-head pairwise duels**, Telly builds an unshakeable personal set of **Rankings** (segregating the **Movie Rankings** from the **Series & Anime Rankings** to avoid apples-to-oranges comparisons), calculates real-time friend **Taste Match %**, and eliminates couch paralysis with the **"Two-to-Watch"** co-watching decider.

---

## 📂 Project Documentation (`docs/`)

All product specifications, architecture documentation, design systems, and roadmap tickets are consolidated in the [**`docs/`**](./docs/) directory:

| Section | Location | Scope & Contents |
| :--- | :--- | :--- |
| 📚 **Feature Specifications** | [`docs/features/`](./docs/features/) | 9 comprehensive feature specs (Onboarding, Duel Engine, Series vs. Seasons, Social Feeds, Taste Match, Profile Rankings, Discovery, Anime Integration, Movie Integration). |
| 🎨 **UI/UX Design System** | [`docs/design_system/`](./docs/design_system/) | Design philosophy (*Midnight Cathode* OLED), component library, screen-by-screen specifications (`SCR-01` to `SCR-20`), and user interaction gesture flows. |
| 🛠️ **Admin & Adjacent Systems** | [`docs/adjacent_systems/`](./docs/adjacent_systems/) | Social/SMS auth flows, profile customization, settings hierarchy, viral sharing studio (Instagram Story cards), and trust & safety moderation. |
| ⚙️ **Technical Architecture** | [`docs/technical_architecture/`](./docs/technical_architecture/) | Tech stack (Flutter 3.24+, Supabase, Drift), PostgreSQL schema & stored procs, TMDB/JustWatch APIs, offline sync, DevOps CI/CD, and the **Test Pyramid (70/20/10)**. |
| 📅 **Roadmap & Work Tracking** | [`docs/ROADMAP.md`](./docs/ROADMAP.md) · [`docs/process/WORKFLOW.md`](./docs/process/WORKFLOW.md) | Now / Next / Later themes; work is tracked as GitHub issues on the [Telly board](https://github.com/users/kandraos3/projects/1). Sprints 1–6 are archived in [`docs/history/`](./docs/history/). |
| 🗄️ **Database Schemas & Seeds** | [`supabase/`](./supabase/) | Executable migrations (`supabase/migrations/`), pgTAP tests (`supabase/tests/`) and the 50-title recognition seed (`supabase/seed.sql`). |
| ⚖️ **Legal & Policies** | [`docs/legal/`](./docs/legal/) | App Store & Google Play compliant Privacy Policy and Terms of Service (EULA). |
| 📖 **Master Documentation Index** | [`docs/README.md`](./docs/README.md) | Full architectural index with complete summary tables for all engineering modules. |

---

## 🏛️ Repository Structure

```
Telly/
├── docs/                                  # Complete product & engineering documentation
│   ├── features/                          # 01-09 Feature Specifications
│   ├── design_system/                     # 01-04 Design System & Screen Specs
│   ├── adjacent_systems/                  # 01-05 Auth, Profile, Settings & Viral Studio
│   ├── technical_architecture/            # 01-06 Architecture, Schemas, APIs & Test Pyramid
│   ├── database/                          # SQL migrations and seed datasets
│   │   ├── migrations/01_initial_schema.sql
│   │   └── seeds/top_50_shows_seed.sql
│   ├── legal/                             # Privacy Policy & Terms of Service
│   ├── DESIGN_DOCUMENT.md                 # Initial product & technical design document
│   ├── ROADMAP.md                         # Now / Next / Later, linking to epic issues
│   ├── process/WORKFLOW.md                # How work is tracked (issues, board, skills)
│   ├── decisions/                         # Product & architecture decision records
│   ├── inbox/                             # Raw owner input (voice notes, brain dumps)
│   ├── history/                           # Frozen Sprints 1–6 roadmap & handoff
│   └── README.md                          # Full documentation index
├── .env.example                           # Configuration keys template
└── .gitignore                             # Git ignore rules
```

---

## 🚀 Quick Start & Development Setup

1. **Review the Specifications**: Start with the [**Master Documentation Index**](./docs/README.md) and [**Design Philosophy**](./docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md).
2. **See What's Being Worked On**: The [Telly board](https://github.com/users/kandraos3/projects/1) and [**`docs/ROADMAP.md`**](./docs/ROADMAP.md); how tracking works is in [**`docs/process/WORKFLOW.md`**](./docs/process/WORKFLOW.md).
3. **Configure Environment Variables**: Copy [`.env.example`](./.env.example) to `.env` and configure your Supabase, TMDB, and JustWatch API keys.
4. **Deploy Database**: `supabase link --project-ref <ref>` then `supabase db push` (applies [`supabase/migrations/`](./supabase/migrations/)).
