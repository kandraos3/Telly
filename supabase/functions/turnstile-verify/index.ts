// Supabase Edge Function: Cloudflare Turnstile Bot Verification & Edge Protection
// Conforms to `DEV-504` and `docs/technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md` §1.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const TURNSTILE_VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface TurnstileVerifyRequest {
  token: string;
  ip?: string;
}

interface TurnstileVerifyResponse {
  success: boolean;
  "error-codes"?: string[];
  challenge_ts?: string;
  hostname?: string;
  action?: string;
  cdata?: string;
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed. Use POST." }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const secretKey = Deno.env.get("TURNSTILE_SECRET_KEY") || "1x0000000000000000000000000000000AA"; // Cloudflare testing key
    const body: TurnstileVerifyRequest = await req.json();

    if (!body.token) {
      return new Response(
        JSON.stringify({ error: "Missing required 'token' parameter" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const formData = new FormData();
    formData.append("secret", secretKey);
    formData.append("response", body.token);
    if (body.ip) {
      formData.append("remoteip", body.ip);
    }

    const verifyRes = await fetch(TURNSTILE_VERIFY_URL, {
      method: "POST",
      body: formData,
    });

    const verifyData: TurnstileVerifyResponse = await verifyRes.json();

    if (!verifyData.success) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Turnstile bot challenge failed",
          codes: verifyData["error-codes"],
        }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        challenge_ts: verifyData.challenge_ts,
        hostname: verifyData.hostname,
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
          "Cache-Control": "no-store, max-age=0",
        },
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: "Internal server error during turnstile verification", details: String(error) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

