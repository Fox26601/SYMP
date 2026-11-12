"use client";

import { useMemo, useState } from "react";
import { createPublicClient, createWalletClient, custom, formatUnits, http, parseUnits } from "viem";
import { base, baseSepolia } from "viem/chains";

const SEED_ABI = [
  {
    type: "function",
    name: "contribute",
    stateMutability: "nonpayable",
    inputs: [{ name: "usdcAmount", type: "uint256" }],
    outputs: [],
  },
  {
    type: "function",
    name: "totalRaisedUsdc",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "hardCapUsdc",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "softCapUsdc",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }],
  },
] as const;

const ERC20_ABI = [
  {
    type: "function",
    name: "approve",
    stateMutability: "nonpayable",
    inputs: [
      { name: "spender", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ type: "bool" }],
  },
  {
    type: "function",
    name: "allowance",
    stateMutability: "view",
    inputs: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
    ],
    outputs: [{ type: "uint256" }],
  },
] as const;

function chainFromEnv() {
  const id = Number(process.env.NEXT_PUBLIC_CHAIN_ID || "8453");
  return id === 84532 ? baseSepolia : base;
}

export function SeedContribute() {
  const sale = (process.env.NEXT_PUBLIC_SEED_SALE || "") as `0x${string}`;
  const usdc = (process.env.NEXT_PUBLIC_USDC || "") as `0x${string}`;
  const rpc = process.env.NEXT_PUBLIC_RPC_URL || "";
  const [amount, setAmount] = useState("10");
  const [account, setAccount] = useState<string>("");
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState("");
  const [raised, setRaised] = useState<string>("—");
  const [caps, setCaps] = useState({ soft: "—", hard: "—" });

  const configured = Boolean(sale && usdc && sale.startsWith("0x") && usdc.startsWith("0x"));
  const chain = useMemo(() => chainFromEnv(), []);

  async function refreshCaps() {
    if (!configured) return;
    const client = createPublicClient({ chain, transport: http(rpc || undefined) });
    const [t, s, h] = await Promise.all([
      client.readContract({ address: sale, abi: SEED_ABI, functionName: "totalRaisedUsdc" }),
      client.readContract({ address: sale, abi: SEED_ABI, functionName: "softCapUsdc" }),
      client.readContract({ address: sale, abi: SEED_ABI, functionName: "hardCapUsdc" }),
    ]);
    setRaised(formatUnits(t, 6));
    setCaps({ soft: formatUnits(s, 6), hard: formatUnits(h, 6) });
  }

  async function connect() {
    const eth = (window as unknown as { ethereum?: unknown }).ethereum;
    if (!eth) {
      setMsg("Install a wallet (e.g. MetaMask / Coinbase Wallet).");
      return;
    }
    const wallet = createWalletClient({ chain, transport: custom(eth as never) });
    const [addr] = await wallet.requestAddresses();
    setAccount(addr);
    setMsg("");
    await refreshCaps();
  }

  async function contribute() {
    if (!configured || !account) return;
    const eth = (window as unknown as { ethereum?: unknown }).ethereum;
    if (!eth) return;
    setBusy(true);
    setMsg("");
    try {
      const value = parseUnits(amount || "0", 6);
      const publicClient = createPublicClient({ chain, transport: http(rpc || undefined) });
      const wallet = createWalletClient({ account: account as `0x${string}`, chain, transport: custom(eth as never) });
      const allowance = await publicClient.readContract({
        address: usdc,
        abi: ERC20_ABI,
        functionName: "allowance",
        args: [account as `0x${string}`, sale],
      });
      if (allowance < value) {
        const approveHash = await wallet.writeContract({
          address: usdc,
          abi: ERC20_ABI,
          functionName: "approve",
          args: [sale, value],
        });
        await publicClient.waitForTransactionReceipt({ hash: approveHash });
      }
      const hash = await wallet.writeContract({
        address: sale,
        abi: SEED_ABI,
        functionName: "contribute",
        args: [value],
      });
      await publicClient.waitForTransactionReceipt({ hash });
      setMsg(`Contributed. Tx ${hash.slice(0, 10)}…`);
      await refreshCaps();
    } catch (e) {
      setMsg(e instanceof Error ? e.message : "Contribute failed");
    } finally {
      setBusy(false);
    }
  }

  if (!configured) {
    return (
      <p className="muted">
        Seed contracts are not configured yet. Join the waitlist; contribute opens 1 Jan 2029 when addresses are set.
      </p>
    );
  }

  return (
    <div className="seed-box">
      <p className="muted">
        Raised: {raised} / soft {caps.soft} / hard {caps.hard} USDC
      </p>
      {!account ? (
        <button type="button" onClick={() => void connect()}>
          Connect wallet
        </button>
      ) : (
        <>
          <p className="muted">Connected: {account.slice(0, 6)}…{account.slice(-4)}</p>
          <label>
            USDC amount
            <input type="number" min={10} max={500} step="1" value={amount} onChange={(e) => setAmount(e.target.value)} />
          </label>
          <button type="button" disabled={busy} onClick={() => void contribute()}>
            {busy ? "Confirm in wallet…" : "Contribute USDC"}
          </button>
        </>
      )}
      {msg ? <p className="ok">{msg}</p> : null}
    </div>
  );
}
