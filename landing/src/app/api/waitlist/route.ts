import { NextResponse } from "next/server";
import { addWaitlistEntry } from "@/lib/waitlistStore";
import { isEip55ish } from "@/lib/sale";

const emailRe = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const hits = new Map<string, { n: number; t: number }>();

function rateLimit(ip: string): boolean {
  const now = Date.now();
  const row = hits.get(ip) || { n: 0, t: now };
  if (now - row.t > 60_000) {
    hits.set(ip, { n: 1, t: now });
    return true;
  }
  if (row.n >= 10) return false;
  row.n += 1;
  hits.set(ip, row);
  return true;
}

export async function POST(req: Request) {
  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "local";
  if (!rateLimit(ip)) {
    return NextResponse.json({ ok: false, error: "rate_limited" }, { status: 429 });
  }

  let body: { email?: string; wallet?: string; company?: string };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ ok: false, error: "invalid_json" }, { status: 400 });
  }

  // honeypot
  if (body.company) {
    return NextResponse.json({ ok: true });
  }

  const email = String(body.email || "")
    .trim()
    .toLowerCase();
  if (!emailRe.test(email) || email.length > 254) {
    return NextResponse.json({ ok: false, error: "invalid_email" }, { status: 400 });
  }

  let wallet = String(body.wallet || "").trim();
  if (wallet) {
    if (!isEip55ish(wallet)) {
      return NextResponse.json({ ok: false, error: "invalid_wallet" }, { status: 400 });
    }
  } else {
    wallet = "";
  }

  try {
    const status = await addWaitlistEntry({
      email,
      wallet: wallet || undefined,
      createdAt: new Date().toISOString(),
    });
    if (status === "duplicate") {
      return NextResponse.json({ ok: false, error: "duplicate" }, { status: 409 });
    }
    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error("waitlist_store_error", err);
    return NextResponse.json({ ok: false, error: "store_unavailable" }, { status: 503 });
  }
}
