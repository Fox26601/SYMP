"use client";

import { useEffect, useState } from "react";
import { SEED_END, SEED_START, salePhase } from "@/lib/sale";

function fmt(sec: number): string {
  if (sec < 0) sec = 0;
  const d = Math.floor(sec / 86400);
  const h = Math.floor((sec % 86400) / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const s = sec % 60;
  return `${d}d ${h}h ${m}m ${s}s`;
}

export function Countdown() {
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000));
  useEffect(() => {
    const id = setInterval(() => setNow(Math.floor(Date.now() / 1000)), 1000);
    return () => clearInterval(id);
  }, []);

  const phase = salePhase(now);
  const target = phase === "Waitlist" ? SEED_START : phase === "Seed" ? SEED_END : SEED_END;
  const label =
    phase === "Waitlist" ? "Seed opens in" : phase === "Seed" ? "Seed closes in" : "Seed closed";

  return (
    <p className="countdown" aria-live="polite">
      <span className="countdown-label">{label}</span>
      {phase === "Ended" ? null : <strong className="countdown-value">{fmt(target - now)}</strong>}
    </p>
  );
}
