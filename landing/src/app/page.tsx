import { Countdown } from "@/components/Countdown";
import { SeedContribute } from "@/components/SeedContribute";
import { WaitlistForm } from "@/components/WaitlistForm";
import { SALE_PARAMS, TOKENOMICS, salePhase } from "@/lib/sale";

export default function HomePage() {
  const phase = salePhase();

  return (
    <main className="shell">
      <header className="hero">
        <p className="muted">Base · ERC-20</p>
        <h1 className="brand">SymbolicPleasures</h1>
        <p className="tagline">
          SYMP is the free-floating token for creator payouts. Seed opens 1 January 2029 — join the waitlist now.
        </p>
        <Countdown />
        <div className="cta-row">
          {phase === "Waitlist" ? (
            <a className="btn" href="#waitlist">
              Join waitlist
            </a>
          ) : null}
          {phase === "Seed" ? (
            <a className="btn" href="#seed">
              Contribute USDC
            </a>
          ) : null}
          <a className="btn btn-ghost" href="#tokenomics">
            Tokenomics
          </a>
        </div>
      </header>

      <section id="pitch">
        <h2>Pitch</h2>
        <p className="lead">
          Creators earn platform tokens and withdraw value on-chain. SYMP is purchased on Uniswap at payout time — no
          inflationary minting per withdrawal. Seed capital bootstraps liquidity so early participants and creators share
          one market.
        </p>
        <ol className="muted">
          <li>Waitlist (now → 31 Dec 2028)</li>
          <li>On-chain seed sale (1–12 Jan 2029 UTC)</li>
          <li>Uniswap v3 pool + creator payout rail</li>
        </ol>
      </section>

      <section id="tokenomics">
        <h2>Tokenomics</h2>
        <p className="lead">Fixed supply 1,000,000,000 SYMP. No admin mint after deploy.</p>
        <table>
          <thead>
            <tr>
              <th>Bucket</th>
              <th>Share</th>
              <th>Amount</th>
              <th>Use</th>
            </tr>
          </thead>
          <tbody>
            {TOKENOMICS.map((row) => (
              <tr key={row.bucket}>
                <td>{row.bucket}</td>
                <td>{row.pct}</td>
                <td>{row.amount}</td>
                <td>{row.use}</td>
              </tr>
            ))}
          </tbody>
        </table>
        <ul className="muted">
          <li>Seed price: {SALE_PARAMS.price}</li>
          <li>
            Caps: soft {SALE_PARAMS.softCap}, hard {SALE_PARAMS.hardCap}; min {SALE_PARAMS.min}, max/wallet{" "}
            {SALE_PARAMS.maxWallet}
          </li>
          <li>Window: {SALE_PARAMS.window}</li>
        </ul>
      </section>

      {phase === "Waitlist" ? (
        <section id="waitlist">
          <h2>Waitlist</h2>
          <p className="lead">No payment now. We will remind you before the seed opens.</p>
          <WaitlistForm />
        </section>
      ) : null}

      {phase === "Seed" ? (
        <section id="seed">
          <h2>Seed sale</h2>
          <p className="lead">Contribute USDC and receive SYMP instantly at the seed price.</p>
          <SeedContribute />
        </section>
      ) : null}

      {phase === "Ended" ? (
        <section id="ended">
          <h2>Sale closed</h2>
          <p className="lead">The seed window ended 12 Jan 2029. Pool and market links will appear here when live.</p>
        </section>
      ) : null}

      <section id="faq">
        <h2>FAQ</h2>
        <p className="muted">
          <strong>Is this investment advice?</strong> No. SYMP is experimental software. You can lose all funds you
          contribute.
        </p>
        <p className="muted">
          <strong>When can I buy?</strong> Only between 1 Jan 2029 00:00 UTC and 12 Jan 2029 23:59:59 UTC, while caps
          remain.
        </p>
        <p className="muted">
          <strong>Network?</strong> Base (Ethereum L2). Same ERC-20 wallets.
        </p>
      </section>

      <section>
        <h2>Disclaimer</h2>
        <p className="disclaimer">
          SymbolicPleasures / SYMP is not a registered security offering. Nothing on this site is an offer to sell or a
          solicitation to buy securities. Crypto-asset rules (including MiCA in the EU) may restrict participation. Do
          not contribute funds you cannot afford to lose. No yield, listing, or price appreciation is promised.
        </p>
      </section>

      <footer>
        <p>SymbolicPleasures · SYMP · Base</p>
      </footer>
    </main>
  );
}
