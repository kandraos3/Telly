# Adjacent Systems Spec 03: Complete Settings & Preferences Architecture

## 1. Overview & Information Architecture
The Settings hub in **Telly** provides centralized control over account security, active streaming subscriptions, notification triggers, display/haptic ergonomics, and storage caching.

```
┌────────────────────────────────────────────────────────┐
│                        SETTINGS                        │
├────────────────────────────────────────────────────────┤
│  ACCOUNT & SECURITY                                    │
│  • Account Details (Phone, Email, Linked Auth)         │
│  • Active Sessions & Connected Devices                 │
│  • Biometric Unlock (Face ID / Fingerprint)            │
│                                                        │
│  ENTERTAINMENT & SERVICES                              │
│  • Manage Streaming Subscriptions (12 Services)        │
│  • Region & Country Settings (For JustWatch Lookup)    │
│  • Streaming Filter Defaults (Include Free / Rentals)  │
│                                                        │
│  NOTIFICATIONS & NOTIFICATIONS MATRIX                  │
│  • Friend Activity & Upset Alerts                      │
│  • Shared Finale Airings & Premieres                   │
│  • "Leaving Soon" Expiration Warnings                  │
│  • Quiet Hours & Frequency Throttle                    │
│                                                        │
│  APPEARANCE & SENSORY                                  │
│  • Theme: OLED Pure Black vs Midnight Slate            │
│  • Haptic Feedback Intensity (Full / Subtle / Off)     │
│  • Reduced Motion (Accessible Transitions)             │
│  • Autoplay Video Previews (Wi-Fi Only / Never)        │
│                                                        │
│  DATA & STORAGE                                        │
│  • Offline Cache Size & Synced Data                    │
│  • Clear Cached Backdrops & Artwork                    │
│  • Export Canon (CSV / Notion / Letterboxd)            │
│                                                        │
│  ABOUT & SUPPORT                                       │
│  • Version 1.0.0 (Build 412)                           │
│  • Terms of Service & Privacy Policy                   │
│  • Log Out / Delete Account                            │
└────────────────────────────────────────────────────────┘
```

---

## 2. Screen Specifications & Sub-Settings

### Screen S1: Main Settings Hub
```
┌────────────────────────────────────────────────────────┐
│ [← Back]                   SETTINGS                    │
├────────────────────────────────────────────────────────┤
│  (👤) Jordan Miller                                    │
│  @jordan • Telly Pro Member 👑                         │
│  [ Edit Profile & Showcases → ]                        │
│                                                        │
│  ━ PREFERENCES ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  📺 Streaming Subscriptions               (6 Active) > │
│  🌸 Connected Anime Accounts     (AniList: @jordan)  > │
│  🔔 Notifications                                    > │
│  📳 Haptics & Motion                     (Full Haptics)>│
│  🔒 Privacy & Ghost Mode                  (Public)   > │
│                                                        │
│  ━ DATA & EXPORTS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  💾 Storage & Offline Sync                (42 MB)    > │
│  📤 Export My TV Canon                               > │
│                                                        │
│  ━ LEGAL & SESSION ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  📜 Terms & Privacy                                  > │
│  🚪 Log Out @jordan                                  > │
│  💀 Delete Account...                                > │
└────────────────────────────────────────────────────────┘
```

---

### Screen S2: Streaming Subscriptions & Regional Calibration
- **Country / Region Selector:** Determines the localized catalog from JustWatch (e.g., United States, United Kingdom, Canada, Australia, Germany, etc.).
- **Platform Matrix:** Multi-toggle grid allowing users to check off active subscriptions (Netflix, Max, Apple TV+, Hulu, Disney+, Prime, Paramount+, Peacock, Criterion, etc.).
- **Rent / Buy Filter Toggle:**
  - `[ ] Include Paid Rentals (Apple TV / Amazon Store)` (Default: Off, to prevent showing \$3.99 rentals when users want subscription streaming).
  - `[✓] Include Free Streaming Services (Tubi, Pluto, Kanopy)` (Default: Off).

---

### Screen S3: Granular Notifications Matrix

Users can toggle individual push notification categories to maintain high signal-to-noise ratio:

| Notification Category | Description | Default State |
| :--- | :--- | :--- |
| **Friend Finished Finale** | Alert when a friend finishes the finale of a series you’ve completed | **ON** |
| **Friend Upset on Your #1** | Alert when a friend rates a show that disputes your #1 favorite | **ON** |
| **Spicy Upsets in Circle** | Global or Squad high-variance controversies | **ON** |
| **Leaving Soon Alert** | Show on your Watchlist is leaving your streaming service in $< 7\text{ days}$ | **ON** |
| **Comment Replies & Tags** | When someone replies to your review or tags your handle | **ON** |
| **Weekly Squad Digest** | Push on Sunday evening with your friend circle’s updated leaderboard | **OFF** |
| **Marketing & New Features**| Feature releases, Telly Wrapped launch announcements | **OFF** |

#### Quiet Hours Configuration:
- `Enable Quiet Hours`: Toggle (Default: 10:00 PM – 9:00 AM).
- During quiet hours, non-urgent notifications (digests, upsets) are queued and delivered as a morning bundle.

---

### Screen S4: Sensory & Ergonomics Settings

- **OLED Pure Black Mode:**
  - `True OLED Black (#08090C)` (Default): Zero battery consumption on OLED displays.
  - `Midnight Slate (#141620)`: Slightly softer high-contrast dark gray.
- **Haptic Feedback Engine:**
  - `Full Tactility` (Default): Haptic ticks on duels, swipe triggers, drag-and-drop slots, and reveals.
  - `Subtle Haptics`: Light feedback only for major actions (winner pick, publish).
  - `Disabled`: Zero vibration.
- **Autoplay Video Stills:**
  - `Wi-Fi Only` (Default) | `Always` | `Never (Static posters only)`.
- **Reduced Motion:**
  - Replaces 3D card flips and spring oscillations with simple 150ms opacity cross-fades.

---

### Screen S5: Storage, Offline Cache & Data Hygiene

```
┌────────────────────────────────────────────────────────┐
│ [←]               STORAGE & OFFLINE                    │
├────────────────────────────────────────────────────────┤
│                                                        │
│  LOCAL STORAGE BREAKDOWN                               │
│  • Offline TV Canon Database:       4.2 MB             │
│  • Cached Show Posters & Artwork:  38.1 MB             │
│  • Total Disk Space Used:          42.3 MB             │
│                                                        │
│  CACHE ACTIONS                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  [ 🗑️ Clear Cached Artwork (38.1 MB) ]            │  │
│  └──────────────────────────────────────────────────┘  │
│  (Will re-download on demand over Wi-Fi)               │
│                                                        │
│  OFFLINE SYNC STATUS                                   │
│  • Status: All 94 Rankings Synced to Cloud             │
│  • Last Sync: 2 minutes ago                            │
│  [ Force Cloud Resync Now ]                            │
│                                                        │
└────────────────────────────────────────────────────────┘
```
