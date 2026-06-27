// ============================================================
//  GENERATION Z — Admin backend (Supabase Edge Function)
//  Powers the private admin.html page on your website.
//
//  Deploy in Supabase -> Edge Functions -> Deploy new function
//    name it exactly:  admin
//    turn OFF "Verify JWT" in its settings.
//
//  Add ONE secret (Edge Functions -> Secrets):
//    ADMIN_PASSWORD = whatever password you want for the admin page
//  (SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically.)
// ============================================================

const SUPABASE_URL  = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ADMIN_PASSWORD = Deno.env.get("ADMIN_PASSWORD") ?? "";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

// --- tiny PostgREST helpers (service role bypasses RLS) ---
const db = (path: string, init: RequestInit = {}) =>
  fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: SERVICE_ROLE,
      Authorization: `Bearer ${SERVICE_ROLE}`,
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });

const ALLOWED_TABLES = new Set(["bookings", "orders", "sell_inquiries"]);

// constant-time-ish string compare
function passwordOk(input: string): boolean {
  if (!ADMIN_PASSWORD) return false;
  const a = new TextEncoder().encode(input);
  const b = new TextEncoder().encode(ADMIN_PASSWORD);
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  let payload: any;
  try { payload = await req.json(); } catch { return json({ error: "bad json" }, 400); }

  const { password, action } = payload ?? {};
  if (!passwordOk(String(password ?? ""))) return json({ error: "unauthorized" }, 401);

  try {
    switch (action) {
      // ---- load everything for the dashboard ----
      case "overview": {
        const q = "?select=*&order=created_at.desc";
        const [bk, od, sl, ph, rp] = await Promise.all([
          db(`bookings${q}`).then((r) => r.json()),
          db(`orders${q}`).then((r) => r.json()),
          db(`sell_inquiries${q}`).then((r) => r.json()),
          db(`phones?select=*&order=created_at.desc`).then((r) => r.json()),
          db(`repair_prices?select=*&order=sort_order.asc`).then((r) => r.json()).catch(() => []),
        ]);
        return json({ bookings: bk, orders: od, sell_inquiries: sl, phones: ph, repair_prices: rp });
      }

      // ---- add or edit a repair price (per device model) ----
      case "repair_save": {
        const p = payload.repair ?? {};
        const num = (v: unknown) => (v === "" || v == null || isNaN(Number(v))) ? null : Number(v);
        const row: Record<string, unknown> = {
          brand: p.brand ?? "",
          model: p.model ?? "",
          lcd: num(p.lcd),
          fhd: num(p.fhd),
          oled: num(p.oled),
          original: num(p.original),
          battery: num(p.battery),
          back_glass: num(p.back_glass),
          charging_port: num(p.charging_port),
          rear_camera: num(p.rear_camera),
          speaker: num(p.speaker),
          sort_order: Number.isFinite(Number(p.sort_order)) ? Number(p.sort_order) : 0,
          active: p.active === false ? false : true,
        };
        if (!row.brand || !row.model) return json({ error: "brand and model required" }, 400);
        if (p.id) {
          await db(`repair_prices?id=eq.${p.id}`, {
            method: "PATCH", headers: { Prefer: "return=minimal" }, body: JSON.stringify(row),
          });
        } else {
          await db(`repair_prices`, {
            method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify(row),
          });
        }
        return json({ ok: true });
      }

      // ---- delete a repair price row ----
      case "repair_delete": {
        const { id } = payload;
        await db(`repair_prices?id=eq.${id}`, { method: "DELETE", headers: { Prefer: "return=minimal" } });
        return json({ ok: true });
      }

      // ---- mark a booking/order paid ----
      case "mark_paid": {
        const { table, id } = payload;
        if (!ALLOWED_TABLES.has(table)) return json({ error: "bad table" }, 400);
        await db(`${table}?id=eq.${id}`, {
          method: "PATCH",
          headers: { Prefer: "return=minimal" },
          body: JSON.stringify({ payment_status: "paid" }),
        });
        return json({ ok: true });
      }

      // ---- tick a job done / undone ----
      case "set_done": {
        const { table, id, value } = payload;
        if (!ALLOWED_TABLES.has(table)) return json({ error: "bad table" }, 400);
        await db(`${table}?id=eq.${id}`, {
          method: "PATCH",
          headers: { Prefer: "return=minimal" },
          body: JSON.stringify({ done: !!value }),
        });
        return json({ ok: true });
      }

      // ---- add or edit a phone for sale ----
      case "phone_save": {
        const p = payload.phone ?? {};
        const row: Record<string, unknown> = {
          name: p.name ?? "",
          storage: p.storage ?? null,
          color: p.color ?? null,
          condition: p.condition ?? null,
          price: Number(p.price) || 0,
          image_url: p.image_url ?? null,
          description: p.description ?? null,
          stock: Number.isFinite(Number(p.stock)) ? Number(p.stock) : 1,
        };
        if (p.id) {
          await db(`phones?id=eq.${p.id}`, {
            method: "PATCH",
            headers: { Prefer: "return=minimal" },
            body: JSON.stringify(row),
          });
        } else {
          await db(`phones`, {
            method: "POST",
            headers: { Prefer: "return=minimal" },
            body: JSON.stringify(row),
          });
        }
        return json({ ok: true });
      }

      // ---- delete a phone ----
      case "phone_delete": {
        const { id } = payload;
        await db(`phones?id=eq.${id}`, { method: "DELETE", headers: { Prefer: "return=minimal" } });
        return json({ ok: true });
      }

      default:
        return json({ error: "unknown action" }, 400);
    }
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
