# Adjacent Systems Spec 05: Trust, Safety, Moderation & Back-Office Admin

## 1. Overview & Community Integrity
As a social platform built on personal opinions and cultural debates, **Telly** must protect users from **spoilers, toxic harassment, bad metadata, and malicious bots**, while providing internal team tools to manage platform health.

**Core Pillars:**
1. **User-Facing Safety Tools:** Frictionless reporting, blocking, muting, and proactive spoiler shields.
2. **Back-Office Admin Console (`admin.telly.app`):** Web interface for internal team operations (user moderation, metadata dispute resolution, report triage).
3. **Data Compliance & Account Deletion:** Full GDPR / CCPA self-service data management and account purging.

---

## 2. User-Facing Safety, Reporting & Spoiler Defense

```
┌────────────────────────────────────────────────────────┐
│ [✕ Cancel]             REPORT CONTENT                  │
├────────────────────────────────────────────────────────┤
│  Reporting Jordan's review of SEVERANCE:               │
│                                                        │
│  WHAT IS WRONG WITH THIS POST?                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 🚨 Major Unmarked Spoilers                       │  │
│  │    Reveals major plot twist without spoiler mask │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 🤬 Harassment / Hate Speech                      │  │
│  │    Attacks or insults other users                │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ 🤖 Spam / Commercial Promotion                   │  │
│  │    Selling accounts, links, or bot activity      │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  OPTIONAL DETAILS:                                     │
│  [ Mentioned the character death in line 2...        ] │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │  [ SUBMIT REPORT TO MODERATION ]                 │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ACTIONS FOR YOU:                                      │
│  • [ Mute @jordan's Reviews ]  • [ Block User ]        │
│  • [ Hide "Severance" from Feed until I Finish ]       │
└────────────────────────────────────────────────────────┘
```

### 2.1 The "Show Mute" Shield (Proactive Spoiler Protection)
If a user is currently watching an ongoing hit series (e.g., *House of the Dragon*), they can toggle:
- `🛡️ Mute All Posts about "House of the Dragon"`
- The app automatically hides all feed cards, upsets, and friend comments related to that show until the user marks it as `Finished` or toggles the shield off.

---

## 3. The Back-Office Admin Console (`admin.telly.app`)

A restricted, role-based web dashboard (React / Next.js / Supabase Admin SDK) for the Telly operations team:

```
┌────────────────────────────────────────────────────────────────────────┐
│  TELLY ADMIN OPS        [ Reports (14) ]  [ Metadata ]  [ Users ]  [⚙️]│
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  REPORT TRIAGE QUEUE                                                   │
│  ID: rep_8821  •  Type: UNMARKED_SPOILER  •  Priority: High            │
│  Target: Review by @alex on "The White Lotus S2 Finale"                │
│  Reported by: 6 users in the last 30 minutes                           │
│                                                                        │
│  Content Preview:                                                      │
│  "I can't believe Tanya fell off the boat and died after shooting them"│
│                                                                        │
│  ACTIONS:                                                              │
│  [ 🙈 Force Mask as Spoiler ]   [ 🗑️ Delete Review ]   [ ⚠️ Warn User ] │
│  [ Dismiss Report (Valid Take) ]                                       │
│                                                                        │
│  ━ METADATA RE-INDEXING QUEUE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  TMDB ID: 110492 (Severance)                                           │
│  Issue: "Season 2 air date shifted, cast missing Gwendoline Christie"  │
│  [ 🔄 Trigger Full TMDB Cache Refresh ]                                │
│                                                                        │
│  ━ SYSTEM HEALTH & ALGORITHM TUNING ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  • Active Daily Duels: 142,890 battles/day                             │
│  • TMDB API Quota: 64% used (Optimal)                                  │
│  • Upset Threshold: Δ = 0.25 (Spicy) [ Adjust Slider ]                 │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### 3.1 Admin Roles & Permissions
- **Tier 1 (Community Moderator):** Can triage reports, apply spoiler masks, hide abusive comments, and issue 24-hour timeouts.
- **Tier 2 (Content Manager):** Can force refresh TMDB show metadata, update JustWatch streaming availability mappings, and manage featured editorial lists.
- **Tier 3 (Super Admin):** User account bans, privacy audit logs, database schema migrations, and algorithm parameter adjustments.

---

## 4. GDPR / CCPA Compliance & Account Deletion

### 4.1 Automated 30-Day Deletion Grace Period
When a user selects **Settings $\rightarrow$ Delete Account**:
1. **Verification Prompt:** Must re-authenticate with Apple ID / SMS OTP.
2. **Confirmation Sheet:** Explains that all 94 rankings, duel history, reviews, and friend connections will be scheduled for permanent destruction.
3. **Deactivation State:**
   - Profile immediately becomes invisible to all users and feeds.
   - User has 30 days to log back in and cancel deletion (*"Welcome back! Your deletion has been cancelled"*).
4. **Permanent Purge (Cron Worker):**
   - At day 31, a background worker runs `DELETE FROM users WHERE id = user_id CASCADE;`
   - Irreversibly purges all data from PostgreSQL, Redis caches, and S3 image buckets.
