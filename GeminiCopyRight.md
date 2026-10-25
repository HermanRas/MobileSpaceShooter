# Google Gemini output: the terms as they stand

MSP ships art the project owner generated with Google Gemini on a consumer subscription:
UI chrome, icons, tile materials, part sprites, portraits and station art. Every generated
file is declared in [`game/assets/LICENCES.md`](game/assets/LICENCES.md). This file is the
evidence behind the claim that we may ship it.

⚠️ **These quotes were read for AOD_Mobile on 2026-09-04 and copied here on 2026-10-25.
They haven't been re-read for MSP yet.** Re-read every linked page before MSP's first
public release (PLAN.md 8.8), then update the dates here. Google has moved these terms
before (§1.1).

---

## 1. Which document governs depends on the tier

Which agreement applies is decided by **how** the output was generated, not by who generated it.

| Tier | The operative document | Read on | Applies to MSP? |
|---|---|---|---|
| **Consumer Gemini** (free, or a paid Google AI Pro / Ultra subscription) | [Google Terms of Service](https://policies.google.com/terms), *Your content* → *License* | effective **30 July 2026** | ✅ **Yes** |
| **Gemini API / AI Studio** | [Gemini API Additional Terms of Service](https://ai.google.dev/gemini-api/terms) | effective **23 March 2026**, updated **28 April 2026** | no |
| **Gemini for Google Workspace** | [Workspace Service Specific Terms](https://workspace.google.com/terms/service-terms/) | current | no |
| **Vertex AI** | [Google Cloud Service Specific Terms](https://cloud.google.com/terms/service-terms) | current | no |

Across all tiers: the [Generative AI Prohibited Use Policy](https://policies.google.com/terms/generative-ai/use-policy)
(last modified **17 December 2024**) and the main ToS section *Don't abuse our services*.

### 1.1 ⚠️ The link that looks right and is retired

<https://policies.google.com/terms/generative-ai> ("Generative AI Additional Terms of
Service", 9 August 2023) says on its own page that it **no longer applies as of 22 May
2024**. Cite the main Terms of Service instead.

---

## 2. The consumer tier

From the [Google Terms of Service](https://policies.google.com/terms), effective **30 July 2026**.

### 2.1 Ownership: Google doesn't claim it

> Some of our services allow you to generate original content. Google won't claim ownership
> over that content.

> Your content remains yours, which means that you retain any intellectual property rights
> that you have in your content.

The second sentence keeps **whatever rights you have**; it doesn't grant any (see §3). The API
terms add that Google "may generate the same or similar content for others", so "not owned
by Google" doesn't mean "exclusively ours".

### 2.2 What's prohibited

- **Passing it off as human-made.** MSP complies by construction: `LICENCES.md` declares
  every generated file, `CREDITS.md` says so on the Credits screen, and this file exists.
  Gemini output also carries a SynthID watermark.
- **Training ML models on it.** This project doesn't.

### 2.3 Commercial use

Permitted on every tier, with no royalty. MSP is free and open source, so this matters least.

---

## 3. Copyright: not settled in our favour

Google's terms answer ownership. Whether the output is copyrightable **at all** is a question
for the law, and under US law the answer is **no**:

- [Copyright Registration Guidance for Works Containing AI-Generated Material](https://www.copyright.gov/ai/ai_policy_guidance.pdf),
  16 March 2023, **88 Fed. Reg. 16,190**: purely AI-generated material isn't registrable.
- [Copyright and Artificial Intelligence, Part 2](https://www.copyright.gov/ai/Copyright-and-Artificial-Intelligence-Part-2-Copyrightability-Report.pdf),
  29 January 2025: human contributions can be registrable; the AI-generated parts can't.
- ***Thaler v. Perlmutter***: the appeals court affirmed refusal to register a purely
  machine-generated work.

**In plain terms:** MSP's generated art is ours to ship and modify, and **probably not ours
to restrict**. Treat it as effectively unprotectable, not as MIT-licensed code. That costs
nothing while the game is free.

---

## 4. Training on our prompts (provenance, not licence)

On a **consumer** account, free or paid, Gemini activity may be used for training unless
**Keep Activity** is turned off at <https://myactivity.google.com/product/gemini>. It's on by
default. A paid consumer subscription isn't an opt-out (the paid **API** and **Workspace**
are). Nothing in this project claims the prompts were withheld from training.

---

## 5. Indemnification: none

Google's generative-AI indemnity covers Google Cloud products (Vertex AI and others), not
consumer subscriptions. MSP has none. Any third-party claim would be ours to carry.

---

## 6. Where this is cited

This file holds the evidence. Two others state the conclusion, so update all three together.

| File | What it says about Gemini output |
|---|---|
| [`CREDITS.md`](CREDITS.md) | The credit entry, shown in-game on the Credits screen |
| [`game/assets/LICENCES.md`](game/assets/LICENCES.md) | A per-file declaration of every generated asset |

`tools/licence_audit.py` checks that every file under `game/assets/` has a row in
`LICENCES.md`. It doesn't check the claims in this file; those are kept up by hand.
