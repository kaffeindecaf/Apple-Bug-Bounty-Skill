---
name: options-thinking
version: 1.0.0
trigger: --thinking
description: Deep chain-of-thought. Higher token budget. Explores multiple paths, evaluates tradeoffs, surface-level then deep-dive before answering.
---

# --thinking: Deep Analysis Mode

Take more tokens. Think longer. Explore multiple hypotheses before settling on an answer.

## Rules

### 1. Surface-level scan first
Before deep analysis, scan the question for what is being asked. State it back explicitly.
```
User asks: "Why does my kernel exploit crash on iPhone 15 but work on iPhone 12?"
Surface scan:
- Two devices, different results
- Same exploit code
- Implies: hardware-specific issue, not a code bug
- Likely candidates: different PAC keys, different T1SZ, different smr_base, different kernel build
```

### 2. Generate hypotheses (minimum 3)
List at least 3 possible explanations. Rank by likelihood.
```
Hypothesis 1 (most likely): T1SZ differs between A12 (iPhone 12) and A16 (iPhone 15).
  A12 uses T1SZ=0x19, A16 uses T1SZ=0x11. SMR decoding uses T1SZ — wrong value corrupts all SMR pointers.

Hypothesis 2: Kernel build is different. iOS version same but kernel build differs per device.
  Check with `sysctl -n kern.osversion` on both devices.

Hypothesis 3: smr_base changed. Was smr_base=1 on older iOS, smr_base=2 on newer.
  If the code hardcodes smr_base, it will fail on devices running newer kernel builds.
```

### 3. Evaluate each hypothesis
For each hypothesis, state:
- What evidence would confirm it
- What evidence would rule it out
- How to test it (concrete command or code)
- Impact if true (what breaks? what else depends on this?)

### 4. Pick the best path
State which hypothesis you are going with and why.
```
Going with Hypothesis 1. Checking T1SZ requires reading the translation table register.
Command: `sysctl -n hw.cputype` on both devices. If different → T1SZ differs → update in offsets.m.
```

### 5. Provide the answer
After the thinking process, provide the concrete answer.

### 6. Cost tracking
Note roughly how many tokens this thinking process used.
```
[Thinking: ~2500 tokens across 3 hypotheses. Selected: Hypothesis 1.]
```

## Interaction with Other Options

- `--thinking --adhd`: Deep analysis, but output is ADHD-formatted. Short answer, no preamble, but the reasoning is visible if you scroll up.
- `--thinking --verbose`: Full chain of thought at maximum detail. All hypotheses, all evidence, all tests. Longest possible output.
- `--thinking --new`: Deep audit. Explore every file, every path, every bug class before ranking findings.
