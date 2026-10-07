// Supabase Edge Function: monthly challenge scheduler (#143). Logic lives in handler.ts.
import { serviceClient } from "../_shared/db.ts";
import { handleScheduler } from "./handler.ts";

Deno.serve((req) => {
  const client = serviceClient();
  return handleScheduler(req, {
    rpc: async (fn, args) => {
      const { data, error } = await client.rpc(fn, args);
      if (error) throw new Error(error.message);
      return data;
    },
    serviceRoleKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
  });
});
