---
name: options-cash
version: 1.0.0
trigger: --cash
description: Money-focused idea generator. Ranks project and feature ideas by earning potential. Same format as --idea but sorted by revenue instead of difficulty.
---

# --cash: Money-Making Ideas

Same analysis as `--idea` but everything is ranked by earning potential, not difficulty.

## Phase 1: Detect Context

Same as `--idea`: empty dir → project ideas. Existing project → feature ideas.

## Phase 2: Project Ideas (Empty / New)

### Format

```
# Money-Making Project Ideas
Target: [directory or domain]
Generated: [date]

---

## Revenue Tier: $$$

**Project:** [name]

**What it does:** [one-line]

**Revenue model:** [how it makes money — bounty payouts, tool sales, consulting, SaaS, etc.]

**Estimated payout range:** [realistic $ range based on Apple Bounty tiers or market rates]

**Difficulty:** [Easy | Medium | Hard | Expert]

**Time to first payout:** [estimate]

**Pros:**
- [pro 1]

**Cons:**
- [con 1]

**Why this over others:** [what makes this more lucrative than alternatives]

---

## Revenue Tier: $$

...same format but lower earning potential...

---

## Revenue Tier: $

...same format...
```

### Revenue Tier System

- **$$$** — $50K+ potential (matches Apple Bounty kernel tier or equivalent)
- **$$** — $10K-$50K potential (sandbox escape, TCC bypass tier)
- **$** — $0-$10K potential (bug fixes, tools, niche exploits)

## Phase 3: Feature Ideas (Existing Project)

### Format

```
# Money-Making Features for [Project Name]
Repo: [path or URL]
Analyzed: [date]

---

## Revenue Tier: $$$               Usefulness: ★★★★★     Difficulty: Hard

**Feature:** [name]

**What it adds:** [one-line]

**Revenue impact:** [how this feature increases the project's value — more bounties? more users? higher pricing?]

**Estimated value add:** [$ range or percentage increase]

**Pros:**
- [pro 1]

**Cons:**
- [con 1]

**Time to implement:** [estimate]

**Implementation hint:** [where in the code]

---

...repeat for $$ and $ tiers...
```

### Rules

- Rank by revenue potential, not difficulty
- Every estimate must reference Apple Bounty tiers or real market rates
- Be honest — if an idea has no clear revenue path, say so and rate it `$`
- Time-to-payout must be realistic (bug bounties take 3-6 months minimum)
- For consulting/tool ideas: estimate market size and realistic customer count
- Reference `ios-security-pentesting.md §2.1` for Apple Bounty payout tiers

### Payout Reference (Apple Security Bounty 2025-2026)

```
Kernel code execution:    up to $250,000
PPL bypass:               up to $250,000
SEP attack:               up to $250,000
Lockdown mode bypass:     up to $250,000+
PAC bypass:               up to $150,000
Sandbox escape:           up to $100,000
TCC bypass:               up to $100,000
Kernel memory disclosure: up to $25,000
Kernel DoS/panic:         up to $15,000
```
