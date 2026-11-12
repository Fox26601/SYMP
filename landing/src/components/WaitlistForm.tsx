"use client";

import { FormEvent, useState } from "react";

export function WaitlistForm() {
  const [email, setEmail] = useState("");
  const [wallet, setWallet] = useState("");
  const [status, setStatus] = useState<"idle" | "loading" | "ok" | "err">("idle");
  const [message, setMessage] = useState("");

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setStatus("loading");
    setMessage("");
    try {
      const res = await fetch("/api/waitlist", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, wallet, company: "" }),
      });
      const data = (await res.json()) as { ok?: boolean; error?: string };
      if (!res.ok || !data.ok) {
        setStatus("err");
        setMessage(
          data.error === "duplicate"
            ? "Already on the waitlist."
            : data.error === "invalid_wallet"
              ? "Wallet must be a 0x address."
              : "Could not join. Check email and try again.",
        );
        return;
      }
      setStatus("ok");
      setMessage("You're on the list. We'll remind you before 1 Jan 2029.");
      setEmail("");
      setWallet("");
    } catch {
      setStatus("err");
      setMessage("Network error.");
    }
  }

  return (
    <form className="waitlist-form" onSubmit={onSubmit}>
      <label>
        Email
        <input
          type="email"
          required
          autoComplete="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="you@example.com"
        />
      </label>
      <label>
        Wallet (optional)
        <input
          type="text"
          value={wallet}
          onChange={(e) => setWallet(e.target.value)}
          placeholder="0x…"
          spellCheck={false}
        />
      </label>
      {/* honeypot */}
      <input type="text" name="company" tabIndex={-1} autoComplete="off" className="hp" aria-hidden />
      <button type="submit" disabled={status === "loading"}>
        {status === "loading" ? "Joining…" : "Join waitlist"}
      </button>
      {message ? <p className={status === "ok" ? "ok" : "err"}>{message}</p> : null}
    </form>
  );
}
