Source: https://felixrieseberg.com/how-to-be-more-ambitious-a-tutorial-for-humans-with-models/

# How to be more ambitious: A tutorial for humans with models

Felix Rieseberg, 13 October 2026

> Note: this is a summary of the article, not its verbatim text. The sandbox network blocks the site and its mirrors, and the full article is the author's copyrighted work. Read the original at the source URL above.

## Introduction

Claude keeps surprising the author with new feats, but model capabilities are uneven. He quotes Terence Tao: models are "astounding in some directions, while inadequate in others." Ambition is the remedy for people who do not yet get value from these tools. He splits ambition into four types: Speed, Altitude, Depth and Range. He skips Speed because it is well established.

## Altitude

Work at a higher level of abstraction, on the outcome instead of the single task. Ask what you want to happen next and what lies beyond the immediate goal.

- Give the model as much business data as you can. Ask it what changed and why.
- Ask for the three most urgent decisions, with arguments for and against each.
- Ask the model to redesign the process itself (for example, the quarterly review) and run the new design next to the old one.
- Build durable workflows that remove the human from repeated loops, for example by giving the model access to crash reports and test machines.

## Depth

Do the task the way a leading expert would, down to the underlying data, tools and problems.

- Use the instruments top professionals use (databases, statistical models), not only Markdown tables.
- Set deliberately ambitious goals.
- Check assumptions adversarially against raw data.
- Produce new knowledge through simulations and held-out predictions.
- Models should not judge their own work. Get outside validation, ideally a tool the model can run.
- The article gives a reusable prompt that asks the model: what would an expert do, what raw material would they start from, which methods would they use, and what external check would confirm the result is correct.

## Range

Draw on perspectives from several fields. Multi-agent setups make this easier.

- Rewrite nouns as verbs to find the relevant disciplines (for example, "a deck" becomes persuading busy people about cause and effect).
- Assemble a diverse crew: an analyst, an editor, and a red team such as a short seller and a forensic accountant.
- Avoid role-play. Ask the model to do what those professionals actually do.
- Give the model a computer, the ability to install software, and data connectors.

## Speed (Scrapkeep addition, Andrew 2026-10-17)

The article skips Speed as well established. Scrapkeep records it because its old limit is gone: work used to queue behind Andrew's one PC, and cloud threads remove that. Factors:

- Parallel width: one cloud thread per independent unit, and workers inside a thread for independent sub-units. Many small threads beat one long one.
- Sibling sandboxes: long sweeps (red team, bots, bakes, renders) split by seed or pilot across sibling cloud threads, each under its 2 hour cap.
- Cloud gating: smoke, bots, placeholder, lint and red team run in the cloud wherever they are reliable. Only what needs the real GPU (frame times, ACE-Step music, final export proof) waits for the 4080.
- Less queueing behind the machine: shrink what only the machine may do (src/ and assets/ ownership, a wave candidate that lives only on the machine), so a cloud branch can be built, gated and reviewed without waiting for it.
- Short loops: measure time from ask to draft PR, from draft PR to gate verdict, and from gate to merge, and push each down. A playable build beats a plan.
- Speed never skips proof: a fast change still needs its tool check and an independent reviewer.

## We have been here before

Humans have long been limited by what they believe is possible (self-efficacy, in psychology). Goal-setting research shows that specific, hard goals beat "do your best." Examples: George Dantzig solving two unsolved statistics problems he took for homework; Roger Bannister's four-minute mile and the fast repeats that followed; permission to fail improving performance.

Takeaway: set specific, hard goals, treat others' achievements as proof of what is possible, and allow yourself to fail.
