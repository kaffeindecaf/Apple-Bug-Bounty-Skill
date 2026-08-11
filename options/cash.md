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

---

## Phase 4: Career & Freelancing Opportunities

When the user runs `--cash` on an existing skill set or experience level, also surface career paths.

### Format

```
# Career Paths for [Skill Set / Experience Level]
Generated: [date]

---

## Path: [Path Name]

**Role:** [job title]

**What you do:** [one-line description]

**Income range:** [$ range per year or per engagement]

**Difficulty to enter:** [Easy | Medium | Hard | Expert]

**Required skills:**
- [skill 1] — [why it matters]
- [skill 2] — [why it matters]

**How to start:**
1. [concrete first step]
2. [second step]

**Pros:**
- [pro 1]

**Cons:**
- [con 1]

**Realistic timeline:** [how long to first income]

---
```

### Career Path Categories

#### Freelancing / Bug Bounty (Independent)

```
Role: Independent iOS Security Researcher
Income: $0–$250,000+ per year (bounty-dependent)
How: Find bugs, submit to Apple Security Bounty / ZDI / third-party programs
Start: Pick an exploit class from ios-research-methodology.md §1.2, find a variant
Timeline: 3–12 months to first meaningful payout
Risk: High — no guaranteed income, bounty payments take 3–6 months
```

```
Role: iOS Exploit Developer (Contract)
Income: $80,000–$200,000 per year (consulting rates: $200–$500/hr)
How: Develop exploits for red teams, penetration testers, or security vendors
Start: Build a portfolio of working PoCs, publish write-ups, network at conferences
Timeline: 6–18 months to build reputation
Risk: Medium — lumpy income but higher floor than pure bounty hunting
```

```
Role: iOS Jailbreak / Tool Developer
Income: $30,000–$100,000 per year (donations, sponsorships, tool sales)
How: Build and maintain jailbreak tools, tweak frameworks, package managers
Start: Contribute to existing projects (TrollStore, checkm8 tooling, kfd), build a following
Timeline: 3–12 months to first income
Risk: High — income depends on community size and engagement
```

#### Employment (Salaried)

```
Role: iOS Security Engineer (FAANG / Big Tech)
Income: $200,000–$500,000+ total comp
How: Work on Apple platform security at Google, Meta, Apple, Microsoft, etc.
Required: Deep knowledge of XNU internals, proven exploit development, strong C/ObjC
Start: 5+ years experience or equivalent portfolio. Apply to security teams directly.
Difficulty: Hard
```

```
Role: Mobile Security Researcher (Security Vendor)
Income: $120,000–$250,000 total comp
How: Research iOS threats at CrowdStrike, SentinelOne, Zimperium, Lookout, etc.
Required: Reverse engineering, malware analysis, threat intelligence
Start: 3+ years experience. Build iOS malware analysis portfolio.
Difficulty: Medium
```

```
Role: Penetration Tester (iOS Specialist)
Income: $90,000–$180,000
How: Test iOS apps for vulnerabilities at consulting firms or in-house security teams
Required: Frida, Objection, Burp Suite, SSL pinning bypass, OWASP Mobile Top 10
Start: OSCP/OSWE + iOS app testing portfolio
Difficulty: Easy-Medium
```

```
Role: iOS Security Tooling Engineer
Income: $130,000–$220,000
How: Build internal security tooling — fuzzers, static analyzers, reverse engineering tools
Required: Strong Swift/ObjC, compiler internals, automation
Start: Build an open-source iOS security tool, get it adopted
Difficulty: Medium
```

#### Adjacent / Emerging

```
Role: AI + iOS Security Researcher
Income: $180,000–$350,000
How: Use LLMs/ML to automate vulnerability discovery, build AI-assisted reverse engineering tools
Required: ML fundamentals, iOS security, Python, Swift
Start: Publish AI-assisted exploit findings, build an automated bug-finding tool
Difficulty: Hard
```

```
Role: Apple Platform Security Educator / Content Creator
Income: $30,000–$200,000 (courses, sponsorships, consulting)
How: Teach iOS exploit development, publish write-ups, create video courses
Start: Publish consistently for 6–12 months, build an audience
Difficulty: Medium
```

### Rules for Career Advice

- Always state income ranges realistically, not aspirationally
- Reference real job postings and salary data where possible
- Be honest about difficulty — "easy" means "entry-level with basic skills," not "no effort"
- For freelancing: always mention the income volatility risk
- For employment: note location dependence (remote vs on-site, US vs EU vs Asia salary differences)
- If the user has zero experience, recommend the easiest entry path first
- Every path must reference at least one skill from the knowledge base

