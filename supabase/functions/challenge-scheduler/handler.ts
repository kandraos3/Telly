// Monthly challenge scheduler (#143, features/10 §8.4). pg_cron calls it on the 25th and the
// 1st through `_invoke_edge_function`, with the service-role key as Bearer token. It creates
// this month's and next month's calendar challenges (`schedule_calendar_challenges`, which is
// idempotent) and clears featured flags on ended challenges (`expire_featured_challenges`).
import { json } from "../_shared/http.ts";

export interface SchedulerDeps {
  /** Calls a service-role RPC and returns its result. */
  rpc: (fn: string, args?: Record<string, unknown>) => Promise<unknown>;
  serviceRoleKey: string | undefined;
  now?: () => Date;
}

/** First day of the month [offset] months from [d], as YYYY-MM-DD (UTC). */
export function monthStart(d: Date, offset = 0): string {
  const m = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + offset, 1));
  return m.toISOString().substring(0, 10);
}

export async function handleScheduler(req: Request, deps: SchedulerDeps): Promise<Response> {
  if (!deps.serviceRoleKey || req.headers.get("Authorization") !== `Bearer ${deps.serviceRoleKey}`) {
    return json({ error: "Unauthorized" }, 401);
  }
  const now = (deps.now ?? (() => new Date()))();
  try {
    const months = [monthStart(now), monthStart(now, 1)];
    const created: Record<string, number> = {};
    for (const month of months) {
      created[month] = Number(await deps.rpc("schedule_calendar_challenges", { p_month: month }) ?? 0);
    }
    const expired = Number(await deps.rpc("expire_featured_challenges") ?? 0);
    return json({ created, expired });
  } catch (err) {
    return json({ error: `Scheduler failed: ${String(err)}` }, 500);
  }
}
