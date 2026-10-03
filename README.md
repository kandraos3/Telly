# 📺 Telly — The Beli for Movies, TV & Anime

> **"Your personal screen canon. Ranked, shared, settled."**

**Telly** is a modern, social screen entertainment ranking and discovery mobile application designed to bring the viral, pairwise ranking mechanics of **Beli** to movies, television series, and anime.

By eliminating arbitrary, inflated 1–10 star ratings in favor of **head-to-head pairwise duels**, Telly builds an unshakeable personal **Dual Canon** (segregating the **Movie Canon** from the **Series & Anime Canon** to avoid apples-to-oranges comparisons), calculates real-time friend **Taste Match %**, and eliminates couch paralysis with the **"Two-to-Watch"** co-watching decider.

---

## 📂 Project Documentation (`docs/`)

All product specifications, architecture documentation, design systems, and roadmap tickets are consolidated in the [**`docs/`**](./docs/) directory:

| Section | Location | Scope & Contents |
| :--- | :--- | :--- |
| 📚 **Feature Specifications** | [`docs/features/`](./docs/features/) | 9 comprehensive feature specs (Onboarding, Duel Engine, Series vs. Seasons, Social Feeds, Taste Match, Profile Canon, Discovery, Anime Integration, Movie Integration). |
| 🎨 **UI/UX Design System** | [`docs/design_system/`](./docs/design_system/) | Design philosophy (*Midnight Cathode* OLED), component library, screen-by-screen specifications (`SCR-01` to `SCR-20`), and user interaction gesture flows. |
| 🛠️ **Admin & Adjacent Systems** | [`docs/adjacent_systems/`](./docs/adjacent_systems/) | Social/SMS auth flows, profile customization, settings hierarchy, viral sharing studio (Instagram Story cards), and trust & safety moderation. |
| ⚙️ **Technical Architecture** | [`docs/technical_architecture/`](./docs/technical_architecture/) | Tech stack (Flutter 3.24+, Supabase, Drift), PostgreSQL schema & stored procs, TMDB/JustWatch APIs, offline sync, DevOps CI/CD, and the **Test Pyramid (70/20/10)**. |
| 📅 **Engineering Roadmap** | [`docs/PROJECT_ROADMAP_AND_SPRINT_PLAN.md`](./docs/PROJECT_ROADMAP_AND_SPRINT_PLAN.md) | 10-week, 5-sprint production roadmap broken down into 81 granular developer tickets with direct spec references. |
| 🗄️ **Database Schemas & Seeds** | [`docs/database/`](./docs/database/) | Executable SQL schema migration (`01_initial_schema.sql`) and 50-title curated recognition seed data (`top_50_shows_seed.sql`). |
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
│   ├── PROJECT_ROADMAP_AND_SPRINT_PLAN.md # 81-ticket granular sprint roadmap
│   └── README.md                          # Full documentation index
├── .env.example                           # Configuration keys template
└── .gitignore                             # Git ignore rules
```

---

## 🚀 Quick Start & Development Setup

1. **Review the Specifications**: Start with the [**Master Documentation Index**](./docs/README.md) and [**Design Philosophy**](./docs/design_system/01_DESIGN_PHILOSOPHY_AND_STYLE_GUIDE.md).
2. **Review Sprint Tickets**: Check [**`docs/PROJECT_ROADMAP_AND_SPRINT_PLAN.md`**](./docs/PROJECT_ROADMAP_AND_SPRINT_PLAN.md) for granular task breakdowns and acceptance criteria.
3. **Configure Environment Variables**: Copy [`.env.example`](./.env.example) to `.env` and configure your Supabase, TMDB, and JustWatch API keys.
4. **Deploy Database**: Run [`docs/database/migrations/01_initial_schema.sql`](./docs/database/migrations/01_initial_schema.sql) on your Supabase PostgreSQL 16 instance.
