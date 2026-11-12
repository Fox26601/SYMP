import { promises as fs } from "fs";
import path from "path";

export type WaitlistEntry = {
  email: string;
  wallet?: string;
  createdAt: string;
};

const FILE = path.join(process.cwd(), ".data", "waitlist.json");

async function readFileStore(): Promise<WaitlistEntry[]> {
  try {
    const raw = await fs.readFile(FILE, "utf8");
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

async function writeFileStore(entries: WaitlistEntry[]): Promise<void> {
  await fs.mkdir(path.dirname(FILE), { recursive: true });
  await fs.writeFile(FILE, JSON.stringify(entries, null, 2));
}

/** Prefer Vercel KV when KV_REST_API_URL is set; else local JSON file. */
export async function addWaitlistEntry(entry: WaitlistEntry): Promise<"ok" | "duplicate"> {
  const email = entry.email.toLowerCase();
  if (process.env.KV_REST_API_URL && process.env.KV_REST_API_TOKEN) {
    const { kv } = await import("@vercel/kv");
    const key = `waitlist:email:${email}`;
    const existing = await kv.get(key);
    if (existing) return "duplicate";
    await kv.set(key, entry);
    await kv.sadd("waitlist:emails", email);
    return "ok";
  }

  const list = await readFileStore();
  if (list.some((e) => e.email.toLowerCase() === email)) return "duplicate";
  list.push({ ...entry, email });
  await writeFileStore(list);
  return "ok";
}
