# How we write to each other

Ruling cz (Andrew, 11 November 2026). This page is the one home for how a session, a thread or an agent writes anything another reader will act on: a board post, a receipt, a pull request, a brief, a report back, a hand-off, a message to Andrew. What a player reads on a screen has its own rule, [LEGIBILITY.md](../../sketches/core-loop/design-v3/LEGIBILITY.md) section 13.

## The reader

Write for an intelligent reader who has no context. The reader has not seen your tool calls, your reasoning or the files you opened, and may be switching in from other work. On this project the reader is one of these:

- Andrew, often on his phone, between other things. He reads the first lines and the last, and answers the last ask.
- A cloud session. It sees only the repository and pull requests. It cannot see the PC's disk, another session's conversation or anyone's memory.
- A fresh coordinator after a reset or an account change.
- A writer agent, which sees only its brief, or a reviewer, which sees only the diff and the receipt.

## The rules

1. **Make the message stand on its own.** The reader understands it without opening anything else. Carry the key context in the message: which wave, which branch and head, what the change does.
2. **Put the key points in the first few sentences.** What changed, what the reader must do, and what is not done come first. Evidence and method follow.
3. **Order the sentences so each one can be read with only what came before it.** Do not use a name or an idea in line 1 that the reader cannot understand until line 12.
4. **Use plain words and full sentences.** Write in the style of ASD-STE100 Simplified Technical English, the controlled English used for aircraft manuals: short sentences, one idea per sentence, active voice, and the same word for the same thing every time.
5. **Do not use a term or an abbreviation you made up during the work.** Say what the thing is. A registered identifier is fine when it is named once with what it is: "ruling cy, the wave gate rule", "PF-33, the freeze finding", "pull request 750, the wave 36 promotion".
6. **Use a paragraph where ideas connect and bullets for separate items.** A table is for comparing things across the same attributes.
7. **Leave out detail the reader does not need, and keep the context they do.** Short is good. Short and unclear is not.

Where these rules do not apply: code, paths, commands and hashes stay verbatim. Sentence length is not a target, so do not chop a causal chain into fragments. The game's voice and playful touches stay.

## What another session cannot see

A path on one machine is not a reference. `~/scratch/...`, `artifacts/local/...` and "my notes" mean nothing to a reader on another machine. Anything another session needs is one of these:

- a pushed branch and a path on it,
- a pull request or issue link,
- a file in the repository,
- or the decisive lines pasted into the message.

Before a session ends it pushes its branch and copies any kept evidence into the pull request or a pushed branch. Gate receipts live on `scratch/gate-receipts-*` branches ([STATE.md](STATE.md)).

## What each kind of message carries

| Message | Where | It opens with | It also carries |
| --- | --- | --- | --- |
| Claim / Dispatch | Coordinator brief or PR | The unit in plain words and the branch | Base commit (`origin/main`), permitted files |
| Receipt | Pull request comment | `VERDICT <PASS, PASS+NOTES, FAIL, BLOCKED or INCONCLUSIVE> head <sha>` and what changed | Commands run with exit codes and nonzero test counts, evidence level, what was not checked, model and effort |
| Ready | Report back / PR update | "Ready to integrate", the pull request link and its head | Receipt link, anything the Gate must check before merging |
| Raised hand | Coordinator message / PR | `NEEDS: coordinator`, `gpu` or `andrew`, and the question in one sentence | Context inside the question, options, default recommendation |
| Ruling passed on | PR or [DECISIONS.md](DECISIONS.md) | Ruling letter and summary | Andrew's words quoted, date/time UTC, head it applies to |
| Brief to a writer | Spawn brief | End state in one sentence a stranger could act on | Scope, base SHA, acceptance, verify, stop conditions, what is forbidden, what to report ([ORCHESTRATOR.md](../../ORCHESTRATOR.md)) |
| Report back | To coordinator | Verdict and what now works | What ran, what did not, deviations, next step |
| Hand-off | Coordinator / [STATE.md](STATE.md) | Current state in a table | Exact next commands, open calls Andrew can overturn |
| Message to Andrew | Chat | What he must do, or what changed | See below |

## Writing to Andrew

- Lead with what he must do or what changed. Number the steps he must take.
- Ask a decision once, on its own line, with the options and a default. One ask per sentence.
- Put a caution before the step it protects.
- Use his word for a thing. If the code's name differs, give both once.
- Give numbers once, together, on one line or in a table.
- Draw it when the answer has a shape: a flow, a before and after, a comparison.
- Say plainly what is not done and what was not checked.

## Before you send

Read the message as the reader. Three questions decide it:

1. If this were the only message they read today, could they act on it?
2. Does the first sentence say what changed or what they must do?
3. Is every name in it either plain words or introduced before it is used?

Times are UTC with the date, read from the clock and not guessed.
