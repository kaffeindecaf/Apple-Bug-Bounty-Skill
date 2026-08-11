---
name: options-idea
version: 1.0.0
trigger: --idea
description: Project and feature idea generator. Empty folders get project ideas. Existing projects get feature ideas. Ranked by difficulty with pros and cons.
---

# --idea: Project & Feature Ideas

## Phase 1: Detect Context

First, determine what the target is:

- **Empty directory / new project** → generate project ideas (Phase 2)
- **Existing project with code** → generate feature ideas (Phase 3)
- **Existing project, but user specifies scope** → generate ideas within that scope

## Phase 2: Project Ideas (Empty / New)

When the target is empty or the user is starting fresh, generate project ideas based on the domain (iOS security, exploit development, tooling, etc.).

### Format

```
# Project Ideas
Target: [directory or domain]
Generated: [date]

---

## [Difficulty: Easy] Project Name

**What it does:** [one-line description]

**Time estimate:** [hours/days]

**Pros:**
- [pro 1]
- [pro 2]

**Cons:**
- [con 1]
- [con 2]

**Skills needed:** [list of skills from the knowledge base]

---

## [Difficulty: Medium] Project Name

...same format...

---

## [Difficulty: Hard] Project Name

...same format...

---

## [Difficulty: Expert] Project Name

...same format...
```

### Rules

- Minimum 2 ideas per difficulty tier
- Every idea must reference at least one skill from the knowledge base
- Pros and cons must be concrete, not vague ("good learning" is vague, "teaches PAC signing internals" is concrete)
- Time estimates in hours for Easy, days for Medium, weeks for Hard, months for Expert
- Order: Easy → Medium → Hard → Expert

## Phase 3: Feature Ideas (Existing Project)

When the target has existing code, analyze the codebase first (read the build system, entry point, key files). Then generate feature ideas.

### Format

```
# Feature Ideas for [Project Name]
Repo: [path or URL]
Analyzed: [date]

---

## [Difficulty: Easy] Feature Name                Usefulness: ★★★☆☆

**What it adds:** [one-line description]

**Why it is useful:** [concrete benefit — what does the user gain?]

**Time estimate:** [hours]

**Pros:**
- [pro 1]

**Cons:**
- [con 1]

**Implementation hint:** [one-line pointer to where in the code this goes]

---

## [Difficulty: Medium] Feature Name              Usefulness: ★★★★☆

...same format...

---

## [Difficulty: Hard] Feature Name                Usefulness: ★★★★★

...same format...

---

## [Difficulty: Expert] Feature Name              Usefulness: ★★★☆☆

...same format...
```

### Usefulness Scale

- ★☆☆☆☆ — niche, barely moves the needle
- ★★☆☆☆ — nice to have, but few users would notice
- ★★★☆☆ — solid improvement, noticeable value
- ★★★★☆ — significant upgrade, most users benefit
- ★★★★★ — game-changer, transforms the project

### Rules

- Analyze the codebase BEFORE generating ideas (read key files, understand architecture)
- Every feature must be implementable with the existing codebase structure
- Reference specific files and functions in implementation hints
- Order by difficulty within each tier
