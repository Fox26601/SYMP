/** Seed window (UTC) — matches SeedSale.sol */
export const SEED_START = Number(process.env.NEXT_PUBLIC_SEED_START ?? "1861920000");
export const SEED_END = Number(process.env.NEXT_PUBLIC_SEED_END ?? "1862956799");

export type SalePhase = "Waitlist" | "Seed" | "Ended";

export function salePhase(nowSec = Math.floor(Date.now() / 1000)): SalePhase {
  if (nowSec < SEED_START) return "Waitlist";
  if (nowSec <= SEED_END) return "Seed";
  return "Ended";
}

export const TOKENOMICS = [
  { bucket: "SeedSale", pct: "10%", amount: "100M", use: "On-chain USDC sale" },
  { bucket: "Liquidity", pct: "50%", amount: "500M", use: "Uniswap v3 SYMP/USDC" },
  { bucket: "Treasury", pct: "30%", amount: "300M", use: "Reserves / programs" },
  { bucket: "Ops", pct: "10%", amount: "100M", use: "Operator reserve" },
] as const;

export const SALE_PARAMS = {
  price: "1000 SYMP = 1 USDC ($0.001)",
  softCap: "$2,000",
  hardCap: "$10,000",
  min: "$10",
  maxWallet: "$500",
  window: "1 Jan 2029 00:00 UTC – 12 Jan 2029 23:59:59 UTC",
} as const;

export function isEip55ish(addr: string): boolean {
  return /^0x[a-fA-F0-9]{40}$/.test(addr.trim());
}
