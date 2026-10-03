# Cloudflare Turnstile & Edge Caching Architecture (DEV-504)

> **Specification for Cloudflare Edge Proxy, CDN Cache Rules, and Turnstile Bot Protection on `api.telly.app` and `telly.app`.**

---

## 1. Cloudflare Proxy & DNS Routing

- **Domain:** `telly.app`
- **API Domain:** `api.telly.app` (CNAME to Supabase Cloud edge instance with Cloudflare Orange Cloud Proxy enabled).
- **SSL / TLS:** Full (Strict) with TLS 1.3 enforced.
- **HTTP/3 (with QUIC):** Enabled for 0-RTT mobile connection re-establishment.

---

## 2. Cloudflare Cache Rules & TTL Policies

| Route Pattern | Cache Level | Edge TTL | Browser TTL | Purge Strategy |
| :--- | :--- | :--- | :--- | :--- |
| `api.telly.app/functions/v1/tmdb-search*` | Cache Everything | 7 Days | 1 Day | Cache-Tag by TMDB ID |
| `api.telly.app/functions/v1/streaming-availability*` | Cache Everything | 24 Hours | 4 Hours | Key by `(tmdb_id, region)` |
| `image.tmdb.org/t/p/*` (Proxy) | Cache Everything | 30 Days | 7 Days | Stale-While-Revalidate |
| `api.telly.app/functions/v1/turnstile-verify` | Bypass Cache | 0s (`no-store`) | 0s | N/A |
| `api.telly.app/rest/v1/pairwise_duels` | Bypass Cache | 0s | 0s | Realtime WAL |

---

## 3. Bot Protection & Cloudflare Turnstile

1. **SMS Auth Endpoints:** All registration and OTP login requests from mobile clients must present a valid `cf-turnstile-response` token.
2. **Verification Edge Function:** `supabase/functions/turnstile-verify/index.ts` contacts `https://challenges.cloudflare.com/turnstile/v0/siteverify` using backend secret key before Supabase Auth SMS dispatch is permitted.
3. **WAF Rate Limiting:** Enforces maximum 5 OTP requests per phone number / IP address per 15 minutes.

