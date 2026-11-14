# Scrapkeep project threads (claude.ai project "Scrapkeep")

Exported 2026-11-14 from the project's thread listing. The listing tool returns at most the 512 most recently started threads, so threads started before about 2026-10-24T23:39Z may exist and are not listed. Raw listings are in `threads-page-1.json` to `threads-page-6.json` (100 rows each, 11 on page 6), `threads-page-0-new.json` (one thread that started after the first fetch) and `prs.json`. The page files omit two redundant fields per row (`status`, `status_bucket`) and the `session_id` strings were hand-copied, so treat `thread_id`, `title` and the dates as the reliable fields.

Counts: 512 rows in the files, 13 not resolved, 499 resolved. The tool itself said total 512 for the first fetch, and the pages hold 511 rows plus the one new thread. One older row may be missing from the copy. A check query for activity since 2026-11-14T09:00Z matched the files row for row, so every unresolved thread is covered. The PR listing tool returned 40 PRs, all merged or closed, and flagged its own result as truncated. It showed no open PR. The open PRs below come from the thread messages, so their state is the thread's last word, not a live check.

## 1. Threads that are not resolved (13)

| Title | State | Last activity (UTC) | Thread id | Latest message, in short | Open PRs named |
|---|---|---|---|---|---|
| Clean up project and local context | review_ready | 2026-11-14 19:13 | cmsg_01Q3o8RFpavsNskXDb46SG49MCWnH37TPZCkiVoougDZpD | Cleaning for next week. Project memory went from 41 notes to 25 (backup kept). Repo docs fix is PR 1036 on stage/alpha-w41, review passed with notes, ready for the board to stack. Still to do: archive gate receipts for waves 34 to 39, then one approval list of PC scratch folders to delete (about 570 GB), then the library pass after the PC sync ends. | 1036 |
| Drive the wave 40 board | working | 2026-11-14 18:44 | cmsg_01Q3o8RFpavsNskXDb46SG492pndiGAi6BAbp1uYpMJZC1 | Board thread winding down because Andrew pauses work until next week. Wave 40 is on main (PR 1011), stage/alpha-w41 is cut (board issue 1012) with 24 PRs stacked, and the PC finishes one last band run for PR 845 then stops. PR 1035 is recorded as next up. | 845, 1035; PRs 1007 to 1032 are stacked on stage/alpha-w41 |
| Pack world 1 with points of interest | blocked | 2026-11-14 18:43 | cmsg_01Q3o8RFpavsNskXDb46SG49MHij7V9ia1ZqPEYBXFBY3u | Paused. Draft PR 1035 adds yard flags, a siren mast, a striped weighbridge plate and breakable crates, and fixes the failing yard test. It waits on the board's PC stills. The floating flume trough is not started and is first in next week's hand-off. | 1035 (draft) |
| Sync project to PC for account switch | review_ready | 2026-11-14 19:09 | cmsg_01Q3o8RFpavsNskXDb46SG497dstg6jYbp9M7JwqPwzzZN | Saving everything before the account switch. Git work is pushed: `wip/lobber-tripo`, the stash and one bundle branch of real source edits. Memory, project instructions, Roadmap, Library, Sitting sheet, Decisions and a resume README are saved in the export folder. Still running: the shared-folder copy (about 1,900 files, slow because of a read limit) and this thread export. Then a final done / not done check. | none |
| Upgrade game models with Tripo | done | 2026-11-14 18:37 | cmsg_01Q3o8RFpavsNskXDb46SG49WiLy4Kg4UCqFY8RBqv1ejw | Paused with nothing left only on the PC. PR 1034 (new chaser, footless hooker barrel) is open and stacks after PR 1031 (scooter, parade crew, wheel shed). Left: two small review notes, the PC look, and 255 Studio credits unspent. | 1031, 1034 |
| Rebuild the dam's look | done | 2026-11-14 18:29 | cmsg_01Q3o8RFpavsNskXDb46SG49UZ75tBPKpDgNFaotPYKjg3 | Paused and everything is pushed. One item is the board's: the PC difficulty check for PR 1033, which moves the dam kicker so the camera sees the yard. Its PC picture and bot run already pass. | 1033 (draft) |
| Make ram damage repeat run to run | review_ready | 2026-11-14 16:41 | cmsg_01Q3o8RFpavsNskXDb46SG49UMGWGdo1HwYhidh4PNVLUv | Cause found: same-tick touches were handled in physics-engine order. Fixed with an order set by game state. Draft PR 1027 is up, sketch:fast passes, READY posted to the board. Two of eight trace and band tests are red on the unchanged stage too, so they are not this change's. | 1027 (draft) |
| Tune dam yard and Brindle pressure | review_ready | 2026-11-14 12:24 | cmsg_01Q3o8RFpavsNskXDb46SG49TUmhRtAChoYcoY8p1HUMEL | The harder world 1 stack is back with the board at PR 845 for wave 41. One red is fixed, two are ledgered. The stage 1 Warden break time is 24.87 s against a 25 s floor. Waiting on the board's PC band read. | 845 |
| Audit the whole game | review_ready | 2026-11-14 11:54 | cmsg_01Q3o8RFpavsNskXDb46SG49KRD7vwzpKnuygVBGT1v3JY | Plain Play now ends at Brindle, as Andrew picked. PR 1018 is handed to the board. 184 fast tests and an independent review pass. Not checked: a full played run from the plain entry to a win. | 1018 |
| Let strong builds break Wardens faster | review_ready | 2026-11-14 11:03 | cmsg_01Q3o8RFpavsNskXDb46SG49JaptwGcc76h3UxVETBqVaD | PR 923 is green on wave 41 and handed to the board. An edit says it is now merged into stage/alpha-w41. Open item: refit the quick-break time limits (30 s dam Warden, 20 s flume Warden) after PR 845 lands. | 923 (merged per the thread's edit) |
| Critique world 1 effects | done | 2026-11-12 22:02 | cmsg_01Q3o8RFpavsNskXDb46SG49N12dhivNDTdXEACuaARTBX | Critique doc (PR 855) and PC strips (PRs 884, 913) are stacked. Backlog rows FX-01 to FX-25 exist as issues 872 to 882. One step open: frame-time stress test on an idle 4080, queued on the board thread. | none open |
| Prototype twin-line grapple swinging | done | 2026-11-11 20:17 | cmsg_01Q3o8RFpavsNskXDb46SG49KyNdqbBqhNuLsfswAdE5zd | Andrew chose to park the two-line swing until after the world 1 sitting. PR 771 stays an unstacked draft behind a flag. The thread is left open for his feedback. | 771 (draft, parked) |
| Add Nov 14 sweep reminder | done | 2026-11-10 16:11 | cmsg_01Q3o8RFpavsNskXDb46SG494WhzUBn74hV8bNwWzXyjHM | The Google Calendar connector was not enabled for this project, so no event was made. The agent gave an `.ics` file for Fri Nov 14, 9:00 to 9:15 AM Phoenix time, "w34 gate weekly sweep". | none |

## 2. Open PRs named in thread messages

`list_prs` showed no open PR (it listed merged and closed only, and said its result was truncated). These come from the 12 threads above. The tool gave no head branch for them. Repository: `bananahana720/scrapkeep`. URL pattern: `https://github.com/bananahana720/scrapkeep/pull/<number>`.

| PR | What it does | State per thread | Base branch | Thread |
|---|---|---|---|---|
| 1035 | Weighbridge gantry fades under the ball, striped plate, breakable crates, yard flags, siren mast, taller camp post, yard test fixed | draft, waits on board PC stills | stage/alpha-w41 | Pack world 1 with points of interest |
| 1034 | New chaser and footless hooker barrel (Tripo models) | open, stacks after 1031 | not given | Upgrade game models with Tripo |
| 1033 | Moves the dam apron kicker so the camera sees the yard | draft, waits on board difficulty check | not given | Rebuild the dam's look |
| 1031 | Scooter, parade crew and wheel shed (Tripo models) | open, waiting to be stacked | not given | Upgrade game models with Tripo |
| 1027 | Same-tick touch order fix so ram damage repeats | draft, READY posted | stage/alpha-w41 | Make ram damage repeat run to run |
| 1018 | Plain Play ends at Brindle | open, handed to the board | not given | Audit the whole game |
| 845 | Harder world 1 stack, re-landed on wave 41 (head bd3fdc76) | open, waits on PC band read, not yet stacked | stage/alpha-w41 | Tune dam yard and Brindle pressure |
| 771 | Two-line grapple swing prototype | draft, parked behind a flag | not given | Prototype twin-line grapple swinging |
| 923 | Quick-break cue for Wardens | merged into stage/alpha-w41 per the thread edit | stage/alpha-w41 | Let strong builds break Wardens faster |
| 1036 | Repo docs fix: live state gets one home, pages follow the newest rulings | open, review passed with notes, ready for the board to stack | stage/alpha-w41 | Clean up project and local context |

Also noted: PR 1011 (promote wave 40 to main, merged, `8d92764c`) and board issue 1012 (wave 41).


## 3. All threads (512)

Order is most recently started first, as the tool returned it. Times are UTC. Thread ids start with `cmsg_`.

| # | Title | State | Resolved | Last activity | Thread id |
|---|---|---|---|---|---|
| 1 | Clean up project and local context | review_ready | no | 2026-11-14T19:13:04Z | cmsg_01Q3o8RFpavsNskXDb46SG49MCWnH37TPZCkiVoougDZpD |
| 2 | Drive the wave 40 board | working | no | 2026-11-14T18:44:05Z | cmsg_01Q3o8RFpavsNskXDb46SG492pndiGAi6BAbp1uYpMJZC1 |
| 3 | Pack world 1 with points of interest | blocked | no | 2026-11-14T18:43:55Z | cmsg_01Q3o8RFpavsNskXDb46SG49MHij7V9ia1ZqPEYBXFBY3u |
| 4 | Sync project to PC for account switch | review_ready | no | 2026-11-14T19:09:15Z | cmsg_01Q3o8RFpavsNskXDb46SG497dstg6jYbp9M7JwqPwzzZN |
| 5 | Upgrade game models with Tripo | done | no | 2026-11-14T18:37:43Z | cmsg_01Q3o8RFpavsNskXDb46SG49WiLy4Kg4UCqFY8RBqv1ejw |
| 6 | Rebuild the dam's look | done | no | 2026-11-14T18:29:44Z | cmsg_01Q3o8RFpavsNskXDb46SG49UZ75tBPKpDgNFaotPYKjg3 |
| 7 | Make ram damage repeat run to run | review_ready | no | 2026-11-14T16:41:14Z | cmsg_01Q3o8RFpavsNskXDb46SG49UMGWGdo1HwYhidh4PNVLUv |
| 8 | Model the cog and ground panels | done | yes | 2026-11-14T14:08:49Z | cmsg_01Q3o8RFpavsNskXDb46SG494uG3X7XL9BAGfzn3RCxUzf |
| 9 | Build the queued difficulty rows | review_ready | yes | 2026-11-14T12:49:01Z | cmsg_01Q3o8RFpavsNskXDb46SG4957XMMt2a93j4KT9H6Eii4z |
| 10 | Tune dam yard and Brindle pressure | review_ready | no | 2026-11-14T12:24:21Z | cmsg_01Q3o8RFpavsNskXDb46SG49TUmhRtAChoYcoY8p1HUMEL |
| 11 | Audit the whole game | review_ready | no | 2026-11-14T11:54:36Z | cmsg_01Q3o8RFpavsNskXDb46SG49KRD7vwzpKnuygVBGT1v3JY |
| 12 | Refresh agent context and memory | done | yes | 2026-11-14T11:14:54Z | cmsg_01Q3o8RFpavsNskXDb46SG49EkPz8xYakpwghqRzLzJBC1 |
| 13 | Critique world 1 visual assets | done | yes | 2026-11-14T11:07:04Z | cmsg_01Q3o8RFpavsNskXDb46SG49MkZtnca3SNX2qffHwvmWmh |
| 14 | Polish shell trace and light effects | done | yes | 2026-11-14T11:05:28Z | cmsg_01Q3o8RFpavsNskXDb46SG49MWuSrAV5QijxUJNN5CTMvZ |
| 15 | Move the HUD onto shared tokens | done | yes | 2026-11-14T11:05:23Z | cmsg_01Q3o8RFpavsNskXDb46SG49VSo3BxWQfCooZMTqTVj98H |
| 16 | Let strong builds break Wardens faster | review_ready | no | 2026-11-14T11:03:56Z | cmsg_01Q3o8RFpavsNskXDb46SG49JaptwGcc76h3UxVETBqVaD |
| 17 | Balance effects volume against music | done | yes | 2026-11-14T11:00:20Z | cmsg_01Q3o8RFpavsNskXDb46SG497qrcB2Ntm8UmSC4oGvKcT5 |
| 18 | Adopt ideas from Reddit Claude workflow | done | yes | 2026-11-14T11:00:19Z | cmsg_01Q3o8RFpavsNskXDb46SG495CNKk9dvgye52iz8jcc6CS |
| 19 | Put effects on shared tables | done | yes | 2026-11-14T10:59:16Z | cmsg_01Q3o8RFpavsNskXDb46SG4976sP5XSo8N3gRK1tKCFGyi |
| 20 | Fix hit direction and armour words | done | yes | 2026-11-14T10:59:49Z | cmsg_01Q3o8RFpavsNskXDb46SG49C3C5HBbHa99CoetX8N99Ly |
| 21 | Critique world 1 gameplay design | done | yes | 2026-11-14T10:58:57Z | cmsg_01Q3o8RFpavsNskXDb46SG49WbBRSzgg8UCyCeD2XMoN28 |
| 22 | Run wave 40 bot tests 13-24 | done | yes | 2026-11-14T10:06:46Z | cmsg_01Q3o8RFpavsNskXDb46SG49Ja2BUtM8mFY4JGrUGrdeSz |
| 23 | Run wave 40 bot tests 1-12 | done | yes | 2026-11-14T10:06:06Z | cmsg_01Q3o8RFpavsNskXDb46SG49DmFYpD3BHNE6hHQSp64vVY |
| 24 | Build a UI audit and learning loop | done | yes | 2026-11-14T09:48:58Z | cmsg_01Q3o8RFpavsNskXDb46SG499f9sRFUsrgLB7dEB5TLf3A |
| 25 | Nightly library housekeeping | done | yes | 2026-11-14T09:08:50Z | cmsg_01Q3o8RFpavsNskXDb46SG498o8JXyfxxhA8CnS4UFWE3u |
| 26 | Build verification skills for Scrapkeep | done | yes | 2026-11-14T04:42:59Z | cmsg_01Q3o8RFpavsNskXDb46SG497fmT9qaX51hrV6K7UaGqxB |
| 27 | Redesign the ball mecha's look | done | yes | 2026-11-14T04:33:21Z | cmsg_01Q3o8RFpavsNskXDb46SG49SqFEoa8NSR13JkvEkLXhbc |
| 28 | Rebuild the title screen look | done | yes | 2026-11-13T11:58:00Z | cmsg_01Q3o8RFpavsNskXDb46SG49LJXiwTzuNbYcUstMkHJieD |
| 29 | Add working machines beside routes | done | yes | 2026-11-13T13:49:29Z | cmsg_01Q3o8RFpavsNskXDb46SG49C9JS5SEJGJdLEH5QnFF5fx |
| 30 | Research what Tripo can do | done | yes | 2026-11-13T20:44:51Z | cmsg_01Q3o8RFpavsNskXDb46SG493biqtBJ3eDGKnpyxVTW54c |
| 31 | Fix world 1 frame hitches | done | yes | 2026-11-14T00:56:38Z | cmsg_01Q3o8RFpavsNskXDb46SG49CBBDnRaeZ1tRENNejHV9ud |
| 32 | Evaluate modern-web-guidance for Scrapkeep | done | yes | 2026-11-13T21:56:46Z | cmsg_01Q3o8RFpavsNskXDb46SG49X7UuB64bXDm7gPDRUCmqM8 |
| 33 | Design a hidden hacker character | done | yes | 2026-11-13T21:22:04Z | cmsg_01Q3o8RFpavsNskXDb46SG497aCuwC2635V9bsczcivMSA |
| 34 | Give maps routes and life | done | yes | 2026-11-13T20:09:56Z | cmsg_01Q3o8RFpavsNskXDb46SG4992jEUo6AD7E79sHuPLAomW |
| 35 | Pay out chains and Shift census | done | yes | 2026-11-13T19:30:00Z | cmsg_01Q3o8RFpavsNskXDb46SG495orY3MoFGXS4EUpbgXzwPZ |
| 36 | Make music follow game states | done | yes | 2026-11-13T17:11:34Z | cmsg_01Q3o8RFpavsNskXDb46SG49SfxGXHVxHAzQCYu4x27jbg |
| 37 | Give tiers their own shapes | done | yes | 2026-11-13T12:26:43Z | cmsg_01Q3o8RFpavsNskXDb46SG49EJaYimgSegRJGEzZVi9srD |
| 38 | Rebuild Brindle's armour plates | done | yes | 2026-11-13T12:26:38Z | cmsg_01Q3o8RFpavsNskXDb46SG49QbeQCzkoAC8QiAwJ86QAdi |
| 39 | Add side spots to the flume | done | yes | 2026-11-13T12:11:18Z | cmsg_01Q3o8RFpavsNskXDb46SG49SEJ7QowVyTMmLbFzpSa9XQ |
| 40 | Vary call-ins and Foreman memos | done | yes | 2026-11-13T11:58:01Z | cmsg_01Q3o8RFpavsNskXDb46SG49YZsqEuD6JUgLN6gr71Q7iB |
| 41 | Give crews lamp eyes and deaths | done | yes | 2026-11-13T09:45:52Z | cmsg_01Q3o8RFpavsNskXDb46SG49UySLrcWzCkitRyJgUb4eaX |
| 42 | Make attack indicators less obstructive | done | yes | 2026-11-13T09:44:54Z | cmsg_01Q3o8RFpavsNskXDb46SG49YX64Q3ynoR3sqsaUPg9GQV |
| 43 | Make collisions feel physical | done | yes | 2026-11-13T06:24:33Z | cmsg_01Q3o8RFpavsNskXDb46SG49DrHkLZdNRi5zmoyRt1hYa1 |
| 44 | Draw real models for altars and finds | done | yes | 2026-11-13T04:39:25Z | cmsg_01Q3o8RFpavsNskXDb46SG49Fu9MB9DbSwcsq4pgMqiZLP |
| 45 | Make sounds fit combat and skills | done | yes | 2026-11-13T04:25:27Z | cmsg_01Q3o8RFpavsNskXDb46SG4942cMWewsZddksKwDBDB2na |
| 46 | Fix uncanny enemy look and feel | done | yes | 2026-11-13T03:40:52Z | cmsg_01Q3o8RFpavsNskXDb46SG49J6ZQQrxQXtJY7hDezWBkTt |
| 47 | Build the Brindle reel | done | yes | 2026-11-13T02:50:42Z | cmsg_01Q3o8RFpavsNskXDb46SG49LExLiiwXzN6UuAdFtc6xs2 |
| 48 | Give the crew distinct heads | done | yes | 2026-11-13T01:47:17Z | cmsg_01Q3o8RFpavsNskXDb46SG49RffLj7kXG3y6EqpsQUeiNM |
| 49 | Fix the dam incline snag | done | yes | 2026-11-13T01:21:03Z | cmsg_01Q3o8RFpavsNskXDb46SG49SKzwj98Bq2N6QVdPE5NSvD |
| 50 | Mark where enemy attacks land | done | yes | 2026-11-13T01:17:39Z | cmsg_01Q3o8RFpavsNskXDb46SG49HVAKuvScb8TTD3pMvxWqPc |
| 51 | Gate builds on the stand-in census | done | yes | 2026-11-13T00:43:07Z | cmsg_01Q3o8RFpavsNskXDb46SG49TxygemMkZ2DMGLDR1E8E8u |
| 52 | End the sitting run at Brindle | done | yes | 2026-11-13T00:36:41Z | cmsg_01Q3o8RFpavsNskXDb46SG492YQbqscqgraWeNoKHkMfMs |
| 53 | Build out world 1 and scaling backlog | done | yes | 2026-11-13T00:18:32Z | cmsg_01Q3o8RFpavsNskXDb46SG493MoEneBY4G48owCixqu4LG |
| 54 | Keep pickup stat lines off fights | done | yes | 2026-11-12T22:35:21Z | cmsg_01Q3o8RFpavsNskXDb46SG49RxC5KyU7rNkBJsVwXvcuyR |
| 55 | Give world effects their sounds | done | yes | 2026-11-12T22:35:20Z | cmsg_01Q3o8RFpavsNskXDb46SG49BicFj4Jn3HKmDUbFT8Hzr8 |
| 56 | Make the damage warning audible | done | yes | 2026-11-12T22:35:13Z | cmsg_01Q3o8RFpavsNskXDb46SG4963xgCNCueBRp9LbsHvPsFW |
| 57 | Show cage and detour objectives | done | yes | 2026-11-12T22:35:11Z | cmsg_01Q3o8RFpavsNskXDb46SG49EbmiGFiWkChJNFDuYdqYZN |
| 58 | Make kills and hits read on sand | done | yes | 2026-11-12T22:26:43Z | cmsg_01Q3o8RFpavsNskXDb46SG49T9HGDtaRa4zZm3p13mm4Dm |
| 59 | Point the summary at next goals | done | yes | 2026-11-12T22:07:48Z | cmsg_01Q3o8RFpavsNskXDb46SG499GM896CsFSMHZDatQHsA4C |
| 60 | Teach plating during the run | done | yes | 2026-11-12T22:05:17Z | cmsg_01Q3o8RFpavsNskXDb46SG49TxdUrrEGSFQahuhTvvEcNu |
| 61 | Critique world 1 effects | done | no | 2026-11-12T22:02:46Z | cmsg_01Q3o8RFpavsNskXDb46SG49N12dhivNDTdXEACuaARTBX |
| 62 | Show safe side on yard telegraphs | done | yes | 2026-11-12T21:51:05Z | cmsg_01Q3o8RFpavsNskXDb46SG499Zta7o1Z9rBYnxf72X2SAY |
| 63 | Draw the 13 icons to spec | done | yes | 2026-11-12T21:50:05Z | cmsg_01Q3o8RFpavsNskXDb46SG49FB5QGJiccQhMevH1yMWKuj |
| 64 | Name the rout only once | done | yes | 2026-11-12T21:49:58Z | cmsg_01Q3o8RFpavsNskXDb46SG49LZ3ezwmyuMvB3FU5oN76wr |
| 65 | Make the ability row explain itself | done | yes | 2026-11-12T21:30:35Z | cmsg_01Q3o8RFpavsNskXDb46SG495badu83VHcYroQYAR6665X |
| 66 | Fix music skipping on new run | done | yes | 2026-11-12T20:22:19Z | cmsg_01Q3o8RFpavsNskXDb46SG49HEa7B3kycYSdLYGTpa1sM5 |
| 67 | Lean up PM docs and artifacts | done | yes | 2026-11-12T16:12:06Z | cmsg_01Q3o8RFpavsNskXDb46SG49SW7AEQbujwNH2zQycTYyTv |
| 68 | Close the remaining world 1 gaps | done | yes | 2026-11-12T14:10:37Z | cmsg_01Q3o8RFpavsNskXDb46SG492XHrMX7Lqr98hYxsbvZWZZ |
| 69 | Audit and improve game systems | done | yes | 2026-11-12T03:19:11Z | cmsg_01Q3o8RFpavsNskXDb46SG49CjPxaqGHkjcszPPwVJ7Y6r |
| 70 | Keep a cleared stage's earnings on Continue | done | yes | 2026-11-12T01:25:04Z | cmsg_01Q3o8RFpavsNskXDb46SG49KpQU8yGuRvQsbCv8datuP3 |
| 71 | Speed up test and bot runs | done | yes | 2026-11-12T00:41:36Z | cmsg_01Q3o8RFpavsNskXDb46SG491XopCbrPMjZByiyj8ZroiT |
| 72 | Research faster agent test workflows | done | yes | 2026-11-11T20:52:58Z | cmsg_01Q3o8RFpavsNskXDb46SG497KgSaqWyYk748cVUQhwfQf |
| 73 | Build marked hull and resource sinks | done | yes | 2026-11-11T22:59:17Z | cmsg_01Q3o8RFpavsNskXDb46SG49Uwa5P5FUiSzq46sQLr4xzN |
| 74 | Pace the first-run tips | done | yes | 2026-11-11T22:56:32Z | cmsg_01Q3o8RFpavsNskXDb46SG496inpg9Dowk2YM3e2WWMr1G |
| 75 | Fold build systems into part ladder | done | yes | 2026-11-11T22:56:16Z | cmsg_01Q3o8RFpavsNskXDb46SG49AvKUmZmZMiFASrr3vsPV9B |
| 76 | Balance the world 1 economy | done | yes | 2026-11-11T22:34:51Z | cmsg_01Q3o8RFpavsNskXDb46SG49UuhBFrSLgiErkp6nsUwHiv |
| 77 | Review the build-system fold | done | yes | 2026-11-11T22:23:01Z | cmsg_01Q3o8RFpavsNskXDb46SG49DCc8VdGRobpX3xHCGSU286 |
| 78 | Build Heat, Reservoir and Called Shot | done | yes | 2026-11-11T21:59:14Z | cmsg_01Q3o8RFpavsNskXDb46SG49FgkgRUu9iMFHQrsiuVwjfi |
| 79 | Rebuild game UI for clarity | done | yes | 2026-11-11T20:40:30Z | cmsg_01Q3o8RFpavsNskXDb46SG49Cbj8qSAq4T3yLfUi8keKgx |
| 80 | Fix rare crash at game start | done | yes | 2026-11-11T20:43:53Z | cmsg_01Q3o8RFpavsNskXDb46SG49VDcvSJHBhj6HaZ7UoVPyY5 |
| 81 | Deepen mechanic decisions and feel | done | yes | 2026-11-11T20:40:42Z | cmsg_01Q3o8RFpavsNskXDb46SG49KYXXpw119eGxaWksehH4XZ |
| 82 | Put scrap on the skill lines | done | yes | 2026-11-11T20:40:34Z | cmsg_01Q3o8RFpavsNskXDb46SG4924LzjpvRujN1ZUuFbCyqPY |
| 83 | Prototype twin-line grapple swinging | done | no | 2026-11-11T20:17:55Z | cmsg_01Q3o8RFpavsNskXDb46SG49KyNdqbBqhNuLsfswAdE5zd |
| 84 | Mark caches, cage and rogue sites | done | yes | 2026-11-11T19:42:34Z | cmsg_01Q3o8RFpavsNskXDb46SG491ZWkmGkcRoAHFM3aK2soTa |
| 85 | Fix flume snag and lift skips | done | yes | 2026-11-11T18:19:03Z | cmsg_01Q3o8RFpavsNskXDb46SG49PCmN33ijmfrzG6F5FbkkJt |
| 86 | Add map breathing and rhythm checks | done | yes | 2026-11-11T16:50:41Z | cmsg_01Q3o8RFpavsNskXDb46SG49UX88dnJxZfwyN77GbuSnvs |
| 87 | Clean up cautious carried instructions | done | yes | 2026-11-10T21:36:37Z | cmsg_01Q3o8RFpavsNskXDb46SG491HpC9Y2pMFHgM3yDbphNPD |
| 88 | Continue measuring the gate | done | yes | 2026-11-10T19:47:17Z | cmsg_01Q3o8RFpavsNskXDb46SG494wLDFySBZADiiWQBR27hr8 |
| 89 | Run balance fault Warden guard quarter | done | yes | 2026-11-10T19:45:22Z | cmsg_01Q3o8RFpavsNskXDb46SG495jF32MSHiLwndbagnhzUhr |
| 90 | Run balance faults part 10 | done | yes | 2026-11-10T16:34:38Z | cmsg_01Q3o8RFpavsNskXDb46SG49XhmfVXjifuSK6nqHo7hfLi |
| 91 | Continue world 1 look and feel | done | yes | 2026-11-10T16:12:08Z | cmsg_01Q3o8RFpavsNskXDb46SG49PXpGsavGep4n9kP8FXGUEH |
| 92 | Add Nov 14 sweep reminder | done | no | 2026-11-10T16:11:59Z | cmsg_01Q3o8RFpavsNskXDb46SG494WhzUBn74hV8bNwWzXyjHM |
| 93 | Run balance faults part 8 | done | yes | 2026-11-10T15:56:29Z | cmsg_01Q3o8RFpavsNskXDb46SG49FtMVzyeMvvH48vmw3Ksgp3 |
| 94 | Harmonise game systems like Isaac | done | yes | 2026-11-10T09:09:58Z | cmsg_01Q3o8RFpavsNskXDb46SG49JzeU5DJbFRmmxF3yhpjfQF |
| 95 | Continue technicals and performance | done | yes | 2026-11-10T15:37:26Z | cmsg_01Q3o8RFpavsNskXDb46SG49MvrtAUs8ZCZoW89vxCP8ax |
| 96 | Continue sound and game music | done | yes | 2026-11-10T15:37:22Z | cmsg_01Q3o8RFpavsNskXDb46SG49Y18b2SSvvZ4L6oQJRUX8uR |
| 97 | Continue world 1 game design | done | yes | 2026-11-10T15:37:21Z | cmsg_01Q3o8RFpavsNskXDb46SG49YcNmucKKKdzQHbqCGEtsoM |
| 98 | Continue speeding up testing | done | yes | 2026-11-10T15:37:12Z | cmsg_01Q3o8RFpavsNskXDb46SG49Min6SsfBkPL8LZnKr1xV3D |
| 99 | Finish PC-held world 1 units | done | yes | 2026-11-10T14:03:28Z | cmsg_01Q3o8RFpavsNskXDb46SG49BZySCACpiNrvhCZqykZb6J |
| 100 | Develop visual artist and 3D models | done | yes | 2026-11-10T10:14:05Z | cmsg_01Q3o8RFpavsNskXDb46SG49AcwSC4otXYVvMBJz2BDBTv |
| 101 | Speed up testing and bot runs | failed | yes | 2026-11-10T11:38:41Z | cmsg_01Q3o8RFpavsNskXDb46SG49JaLTpNJNLSvwueqUxDJ8aC |
| 102 | Improve technicals and performance | failed | yes | 2026-11-10T12:33:30Z | cmsg_01Q3o8RFpavsNskXDb46SG49JQYyRCMoNhjBVy3Ghbhsu4 |
| 103 | Plant bugs to measure the gate | failed | yes | 2026-11-10T14:01:31Z | cmsg_01Q3o8RFpavsNskXDb46SG49CHS9WCC78B4zK5hyzA6hL9 |
| 104 | Improve world 1 look and feel | failed | yes | 2026-11-10T14:12:49Z | cmsg_01Q3o8RFpavsNskXDb46SG49GaBjwpVzR4JVo86WmQyYSF |
| 105 | Improve world 1 game design | failed | yes | 2026-11-10T14:54:18Z | cmsg_01Q3o8RFpavsNskXDb46SG49LLAGbnicMLgADEngiLgaEg |
| 106 | Develop sound artist and game music | failed | yes | 2026-11-10T15:10:14Z | cmsg_01Q3o8RFpavsNskXDb46SG49Bo7F7wPu2fBJJU229EqPSe |
| 107 | Run balance faults part 5 | done | yes | 2026-11-10T15:32:51Z | cmsg_01Q3o8RFpavsNskXDb46SG49YXENaTLri4CyvENFMNL8tc |
| 108 | Run balance faults part 11 | done | yes | 2026-11-10T14:38:24Z | cmsg_01Q3o8RFpavsNskXDb46SG49TCDbySac7KZVdzL7ZKh5b5 |
| 109 | Gate bots 16-20 on stage bf58e379 | done | yes | 2026-11-10T14:38:15Z | cmsg_01Q3o8RFpavsNskXDb46SG497Y2aMbLooFSA2T5EdVbK14 |
| 110 | Run balance faults part 7 | done | yes | 2026-11-10T14:33:25Z | cmsg_01Q3o8RFpavsNskXDb46SG49HSZRsZJPiH5o6faW6eqiC1 |
| 111 | Run balance fault regen quarter | done | yes | 2026-11-10T14:29:57Z | cmsg_01Q3o8RFpavsNskXDb46SG49B2dYu8YbnGNzfnKFDo4Zgy |
| 112 | Run balance faults part 12 | done | yes | 2026-11-10T14:23:39Z | cmsg_01Q3o8RFpavsNskXDb46SG492CNFTwE5zTRE5xWhp749mQ |
| 113 | Run balance faults part 6 | done | yes | 2026-11-10T14:15:18Z | cmsg_01Q3o8RFpavsNskXDb46SG49QkhvytFfvKXzJ1wPaKG2Ms |
| 114 | Run balance faults part 9 | done | yes | 2026-11-10T14:01:32Z | cmsg_01Q3o8RFpavsNskXDb46SG49WLhMmbezPc1ot3dPa2P1FN |
| 115 | Gate bands C on stage bf58e379 | done | yes | 2026-11-10T13:04:04Z | cmsg_01Q3o8RFpavsNskXDb46SG49PbvQLaohZRvVy5PEkqLwk2 |
| 116 | Run balance faults part 2 | done | yes | 2026-11-10T12:29:18Z | cmsg_01Q3o8RFpavsNskXDb46SG49B7F8kp7QB1hdW1LrL6kZds |
| 117 | Gate tests 701-1046 on stage bf58e379 | done | yes | 2026-11-10T12:06:46Z | cmsg_01Q3o8RFpavsNskXDb46SG493BPTW3vocTrtrSS9CxADpf |
| 118 | Gate tests 351-700 on stage bf58e379 | done | yes | 2026-11-10T12:02:28Z | cmsg_01Q3o8RFpavsNskXDb46SG49TdyQ8VtQYJdrU8unGJ3Wb2 |
| 119 | Run balance faults part 1 | done | yes | 2026-11-10T11:59:11Z | cmsg_01Q3o8RFpavsNskXDb46SG49TDNgxvwjnG2U3HUVP8cTCu |
| 120 | Gate bands A on stage bf58e379 | done | yes | 2026-11-10T11:53:25Z | cmsg_01Q3o8RFpavsNskXDb46SG497k6qLW3Tr2nboAt548Y6Q1 |
| 121 | Gate bands B on stage bf58e379 | done | yes | 2026-11-10T11:52:45Z | cmsg_01Q3o8RFpavsNskXDb46SG49Nrduf1cRzwZPFb2msEZkgY |
| 122 | Gate tests 1-350 on stage bf58e379 | done | yes | 2026-11-10T11:39:51Z | cmsg_01Q3o8RFpavsNskXDb46SG49PbJFokuazhEkf7BrZobRVY |
| 123 | Gate bots 11-15 on stage bf58e379 | done | yes | 2026-11-10T11:20:37Z | cmsg_01Q3o8RFpavsNskXDb46SG49P4GVFmmuddKg3zGWGhsSLG |
| 124 | Run balance faults part 4 | done | yes | 2026-11-10T11:06:32Z | cmsg_01Q3o8RFpavsNskXDb46SG49J3EdDoyjNXaiJC249sFnVd |
| 125 | Gate bots 6-10 on stage bf58e379 | done | yes | 2026-11-10T10:36:11Z | cmsg_01Q3o8RFpavsNskXDb46SG498B6Py9aJh61vwcnG4FLEFJ |
| 126 | Red team cautious on stage bf58e379 | done | yes | 2026-11-10T10:36:01Z | cmsg_01Q3o8RFpavsNskXDb46SG494rCEctG74W6w9vkBgmt1KR |
| 127 | Gate bots 21-23 on stage bf58e379 | done | yes | 2026-11-10T10:25:47Z | cmsg_01Q3o8RFpavsNskXDb46SG49EtYupw9sxFiPFX7QjrBRAX |
| 128 | Run balance faults part 3 | done | yes | 2026-11-10T10:19:50Z | cmsg_01Q3o8RFpavsNskXDb46SG49CeHQUSZSXUWgk15Hx4tnTq |
| 129 | Gate bots 1-5 on stage bf58e379 | done | yes | 2026-11-10T10:18:13Z | cmsg_01Q3o8RFpavsNskXDb46SG49EQZrUNHAM2yjwUY7ECP4oh |
| 130 | Simplify heading and headless checks | done | yes | 2026-11-10T03:58:28Z | cmsg_01Q3o8RFpavsNskXDb46SG49PPtHgqEG2CsaeY12NT5KFo |
| 131 | Run planted faults part 3 | done | yes | 2026-11-10T03:28:42Z | cmsg_01Q3o8RFpavsNskXDb46SG49Dg8qdxEmR4pCQcgzxysT83 |
| 132 | Improve project workflows | done | yes | 2026-11-10T03:27:00Z | cmsg_01Q3o8RFpavsNskXDb46SG495ArpbXnxEcx1JrTeaSigc3 |
| 133 | Run planted bug block world1 | done | yes | 2026-11-10T03:17:35Z | cmsg_01Q3o8RFpavsNskXDb46SG49Uiw8UB5LjSLPPh6meGX7Zy |
| 134 | Run planted bug block b6 | done | yes | 2026-11-10T03:08:29Z | cmsg_01Q3o8RFpavsNskXDb46SG49GCyuxNCBsMGxacgWT5NJhx |
| 135 | Run planted bug block b2 | done | yes | 2026-11-10T02:59:14Z | cmsg_01Q3o8RFpavsNskXDb46SG49Xt7DbEprtriyuPKwR91KmL |
| 136 | Run planted faults part 2 | done | yes | 2026-11-10T02:59:12Z | cmsg_01Q3o8RFpavsNskXDb46SG49RGfSg6EpQxmpJkBgkpByEP |
| 137 | Vary the dam run to run | blocked | yes | 2026-11-10T02:58:42Z | cmsg_01Q3o8RFpavsNskXDb46SG49Gr8tfcdPK9JWspYsh9Z9Wz |
| 138 | Run planted bug block b3 | done | yes | 2026-11-10T02:49:53Z | cmsg_01Q3o8RFpavsNskXDb46SG49EB3hHU6HL1piMhybohtxeM |
| 139 | Run planted bug block b5 | done | yes | 2026-11-10T02:46:33Z | cmsg_01Q3o8RFpavsNskXDb46SG49YMN8wWCqrxpKb74naVcupK |
| 140 | Run planted bug block b7 | done | yes | 2026-11-10T02:46:24Z | cmsg_01Q3o8RFpavsNskXDb46SG49VgZnTwgunS3up1i9VE4Dws |
| 141 | Run planted bug block b4 | done | yes | 2026-11-10T02:45:35Z | cmsg_01Q3o8RFpavsNskXDb46SG49VtAwZkcyRZ1awUNKWuT7Xt |
| 142 | Run planted faults part 5 | done | yes | 2026-11-10T02:37:30Z | cmsg_01Q3o8RFpavsNskXDb46SG496VrqBRdCfFU8LJg4ctcBzA |
| 143 | Run planted faults part 4 | done | yes | 2026-11-10T02:32:00Z | cmsg_01Q3o8RFpavsNskXDb46SG49MoDDyghRpesctzKX6pvvJ3 |
| 144 | Run planted faults part 1 | done | yes | 2026-11-10T02:08:47Z | cmsg_01Q3o8RFpavsNskXDb46SG4959Dn5LHQGFsq6egvtLVTNN |
| 145 | Lay scrap lines on dam and flume | done | yes | 2026-11-09T23:52:29Z | cmsg_01Q3o8RFpavsNskXDb46SG491hBr3ozxYqsH2nd7U8VHSd |
| 146 | Finish leftover dam fixes | done | yes | 2026-11-09T23:12:28Z | cmsg_01Q3o8RFpavsNskXDb46SG49CMnqLhEEcMadoy9eKAfYm7 |
| 147 | Make kills and chains melodic | done | yes | 2026-11-09T23:02:53Z | cmsg_01Q3o8RFpavsNskXDb46SG494MGbnzbbzLAWp1jpCRuLQG |
| 148 | Fix Brindle charge fling | done | yes | 2026-11-09T22:29:06Z | cmsg_01Q3o8RFpavsNskXDb46SG49VxfCqFGg7NmHKTE5kcTny3 |
| 149 | Gate bots shard 6 on stage 1013c7d1 | done | yes | 2026-11-08T07:36:57Z | cmsg_01Q3o8RFpavsNskXDb46SG49YB96PKGNub9ozi6CkWd1px |
| 150 | Improve death and summary screens | done | yes | 2026-11-09T21:33:33Z | cmsg_01Q3o8RFpavsNskXDb46SG49GKqxHpnF1LiZH4uavs4ked |
| 151 | Sharpen shop and growth choices | done | yes | 2026-11-09T20:59:33Z | cmsg_01Q3o8RFpavsNskXDb46SG495FB7mz3BTJEiypmRR958QE |
| 152 | Pause on focus loss | done | yes | 2026-11-09T20:50:28Z | cmsg_01Q3o8RFpavsNskXDb46SG494Wiuogd2LLWadAcfRvKHQU |
| 153 | Fix screens crash and quit leak | done | yes | 2026-11-09T20:25:48Z | cmsg_01Q3o8RFpavsNskXDb46SG49Dm7mpgpgGdAxeBmwRxS646 |
| 154 | Clean up docs and publish the roadmap | done | yes | 2026-11-08T20:01:28Z | cmsg_01Q3o8RFpavsNskXDb46SG496G1KZFADu3ped42L9c2LNH |
| 155 | Fix world 1 dam frame spikes | done | yes | 2026-10-31T06:07:18Z | cmsg_01Q3o8RFpavsNskXDb46SG49WZqBbKyh4gm2ncAafzAU7J |
| 156 | Deepen modules and simplify interfaces | done | yes | 2026-11-08T23:51:23Z | cmsg_01Q3o8RFpavsNskXDb46SG494tMffGqnJpcr3JCcUweHoJ |
| 157 | Gate bands chunk C on stage 58a6de62 | done | yes | 2026-11-08T23:02:47Z | cmsg_01Q3o8RFpavsNskXDb46SG49YYww6q58frWxGMJwZK7MPh |
| 158 | Gate bands chunk B on stage 58a6de62 | done | yes | 2026-11-08T21:34:19Z | cmsg_01Q3o8RFpavsNskXDb46SG49MbCh9KE3byHUTYnEHV2NQ9 |
| 159 | Gate tests 721-end on stage 58a6de62 | done | yes | 2026-11-08T21:19:59Z | cmsg_01Q3o8RFpavsNskXDb46SG49SaGwqC8LFChWa81hZmTYKS |
| 160 | Gate bands chunk A on stage 58a6de62 | done | yes | 2026-11-08T21:14:03Z | cmsg_01Q3o8RFpavsNskXDb46SG49EYCFaM1dDjggTASf7vYt9S |
| 161 | Remove debug codes from the death screen | done | yes | 2026-11-08T21:07:42Z | cmsg_01Q3o8RFpavsNskXDb46SG49UjCuMfqH6jHiUAZBRREhBM |
| 162 | Gate tests 361-720 on stage 58a6de62 | done | yes | 2026-11-08T21:03:39Z | cmsg_01Q3o8RFpavsNskXDb46SG49BERebXSSnUrdoXoXPT8Kyy |
| 163 | Gate bots shard 5 on stage 58a6de62 | done | yes | 2026-11-08T20:58:19Z | cmsg_01Q3o8RFpavsNskXDb46SG49DrwU9fegFZqpfbfTLhKuT9 |
| 164 | Gate tests 1-360 on stage 58a6de62 | done | yes | 2026-11-08T20:57:20Z | cmsg_01Q3o8RFpavsNskXDb46SG49QnG3Ku3CX48NMHhhhMksKZ |
| 165 | Red-team wave 32 as a first-timer | done | yes | 2026-11-08T20:49:55Z | cmsg_01Q3o8RFpavsNskXDb46SG49LLG9XYTPVmFn3cJsZ1zCKT |
| 166 | Gate bots shard 4 on stage 58a6de62 | done | yes | 2026-11-08T20:47:59Z | cmsg_01Q3o8RFpavsNskXDb46SG493Vdxdd1AxyunV5GgaQrnkp |
| 167 | Gate bots shard 2 on stage 58a6de62 | done | yes | 2026-11-08T20:42:30Z | cmsg_01Q3o8RFpavsNskXDb46SG49Sa3hz4aj9zWWKViodcBkh4 |
| 168 | Gate bots shard 1 on stage 58a6de62 | done | yes | 2026-11-08T20:41:22Z | cmsg_01Q3o8RFpavsNskXDb46SG49HaArAB1J4AaqZUhexJHDAF |
| 169 | Gate bots shard 3 on stage 58a6de62 | done | yes | 2026-11-08T20:29:38Z | cmsg_01Q3o8RFpavsNskXDb46SG494aN8RW2eG7yRrW5n2cEBLi |
| 170 | Gate bots shard 6 on stage 58a6de62 | done | yes | 2026-11-08T20:28:54Z | cmsg_01Q3o8RFpavsNskXDb46SG499gmeXHq99GUNnpkGXwfnsL |
| 171 | Balance game sound and volume mix | done | yes | 2026-11-08T17:41:05Z | cmsg_01Q3o8RFpavsNskXDb46SG49SojbP1pgLghd8QsviC9boa |
| 172 | Gate bands chunk C on stage 07fb5323 | done | yes | 2026-11-08T16:07:45Z | cmsg_01Q3o8RFpavsNskXDb46SG49Tgi9dG5QEvgXnpt1WWPLz5 |
| 173 | Gate bands chunk B on stage 07fb5323 | done | yes | 2026-11-08T15:01:46Z | cmsg_01Q3o8RFpavsNskXDb46SG49BK72WEqq8F5G5F1C63f94C |
| 174 | Find unenforced game invariants | done | yes | 2026-11-08T14:32:46Z | cmsg_01Q3o8RFpavsNskXDb46SG49QWGDDUmebEcFPG9E5pa9So |
| 175 | Gate bands chunk A on stage 07fb5323 | done | yes | 2026-11-08T14:23:24Z | cmsg_01Q3o8RFpavsNskXDb46SG49TFmyNg5JUwiAh7BfKVESMz |
| 176 | Gate bots shard 5 on stage 07fb5323 | done | yes | 2026-11-08T14:14:45Z | cmsg_01Q3o8RFpavsNskXDb46SG49Y6ccwYRk3m4ysxgXgr2UuV |
| 177 | Gate bots shard 4 on stage 07fb5323 | done | yes | 2026-11-08T14:03:42Z | cmsg_01Q3o8RFpavsNskXDb46SG49A3L5v2N7MWAHT1Dy8Siifu |
| 178 | Gate bots shard 2 on stage 07fb5323 | done | yes | 2026-11-08T13:57:56Z | cmsg_01Q3o8RFpavsNskXDb46SG49Rqcx6Xqe3j3kCHUxVvYpM5 |
| 179 | Gate bots shard 6 on stage 07fb5323 | done | yes | 2026-11-08T13:54:14Z | cmsg_01Q3o8RFpavsNskXDb46SG49DkYwTVV2M13MuLQN43mAqr |
| 180 | Gate bots shard 1 on stage 07fb5323 | done | yes | 2026-11-08T13:53:59Z | cmsg_01Q3o8RFpavsNskXDb46SG491EzmK4MwDE7KVQsba7PBCY |
| 181 | Gate bots shard 3 on stage 07fb5323 | done | yes | 2026-11-08T13:47:24Z | cmsg_01Q3o8RFpavsNskXDb46SG49YVu75LmhsA9qkzS76Q6t8v |
| 182 | Gate bands chunk C on stage 0786c1a8 | done | yes | 2026-11-08T12:03:48Z | cmsg_01Q3o8RFpavsNskXDb46SG49RYTiVZsiYbp4pMgs8SQDWV |
| 183 | Gate bands chunk B on stage 0786c1a8 | done | yes | 2026-11-08T11:16:54Z | cmsg_01Q3o8RFpavsNskXDb46SG491oviBzeHqUuHuDtUF7EC6E |
| 184 | Gate tests 691-1086 on stage 0786c1a8 | done | yes | 2026-11-08T11:03:45Z | cmsg_01Q3o8RFpavsNskXDb46SG49CvXApdo5h2Dmq1JUxC71oi |
| 185 | Gate bands chunk A on stage 0786c1a8 | done | yes | 2026-11-08T11:01:18Z | cmsg_01Q3o8RFpavsNskXDb46SG491K1cLqNvcQpycPydK5TH9n |
| 186 | Gate bots shard 5 on stage 0786c1a8 | done | yes | 2026-11-08T10:53:34Z | cmsg_01Q3o8RFpavsNskXDb46SG49RvUE4S1hmxUMmiqkmcuj7j |
| 187 | Gate tests 346-690 on stage 0786c1a8 | done | yes | 2026-11-08T10:49:53Z | cmsg_01Q3o8RFpavsNskXDb46SG49C7FnBWBLsXd7td7pNKngRj |
| 188 | Gate tests 1-345 on stage 0786c1a8 | done | yes | 2026-11-08T10:32:21Z | cmsg_01Q3o8RFpavsNskXDb46SG491zYCDvu8MxmqE6LKJGiVJ3 |
| 189 | Gate bots shard 3 on stage 0786c1a8 | done | yes | 2026-11-08T10:18:54Z | cmsg_01Q3o8RFpavsNskXDb46SG49B4tmDTmE3XqkoQcb8eETdG |
| 190 | Gate bots shard 2 on stage 0786c1a8 | done | yes | 2026-11-08T10:17:08Z | cmsg_01Q3o8RFpavsNskXDb46SG49VNNbbZVgiCAWoBtcRfhsVZ |
| 191 | Gate bots shard 1 on stage 0786c1a8 | done | yes | 2026-11-08T10:17:02Z | cmsg_01Q3o8RFpavsNskXDb46SG49GEj4iQUkhigU5zfLcwapiM |
| 192 | Gate bots shard 4 on stage 0786c1a8 | done | yes | 2026-11-08T10:14:40Z | cmsg_01Q3o8RFpavsNskXDb46SG49Bn9QrUtH4QGc8pqYfbnNcb |
| 193 | Gate bots shard 6 on stage 0786c1a8 | done | yes | 2026-11-08T10:03:39Z | cmsg_01Q3o8RFpavsNskXDb46SG49RS8bY1g5iw8in6LLDdBYJD |
| 194 | Gate bands chunk C on stage 1013c7d1 | done | yes | 2026-11-08T09:26:16Z | cmsg_01Q3o8RFpavsNskXDb46SG49FQtFvkGpTb9SdvsPCba5M9 |
| 195 | Fix claw tow holding freed enemies | done | yes | 2026-11-08T09:13:36Z | cmsg_01Q3o8RFpavsNskXDb46SG49J1MG7Bjnx63shzQqEqng5j |
| 196 | Gate bands chunk B on stage 1013c7d1 | done | yes | 2026-11-08T08:56:41Z | cmsg_01Q3o8RFpavsNskXDb46SG49YbmsoRTD9cm8fsN1MAYGm9 |
| 197 | Red-team wave 31 as a speedrunner | done | yes | 2026-11-08T08:46:28Z | cmsg_01Q3o8RFpavsNskXDb46SG49MYesuTFmr6nViW9dqY4RHX |
| 198 | Make implicit state machines explicit | done | yes | 2026-11-08T08:31:48Z | cmsg_01Q3o8RFpavsNskXDb46SG49SUS9HK5GrpwdazSuWZd99e |
| 199 | Gate tests 691-1085 on stage 1013c7d1 | done | yes | 2026-11-08T08:12:14Z | cmsg_01Q3o8RFpavsNskXDb46SG492AquuoEHkMiQdXRBxwdiZD |
| 200 | Gate bands chunk A on stage 1013c7d1 | done | yes | 2026-11-08T07:59:18Z | cmsg_01Q3o8RFpavsNskXDb46SG49AD8uGLQ8QFeGSLwoTnrGkE |
| 201 | Gate bots shard 5 on stage 1013c7d1 | done | yes | 2026-11-08T07:50:51Z | cmsg_01Q3o8RFpavsNskXDb46SG49AdmF6GR2m5YqGB9XeiQSGX |
| 202 | Gate tests 346-690 on stage 1013c7d1 | done | yes | 2026-11-08T07:36:58Z | cmsg_01Q3o8RFpavsNskXDb46SG49AnQhurAVv1kLvGJD94GUvA |
| 203 | Gate tests 1-345 on stage 1013c7d1 | done | yes | 2026-11-08T07:23:05Z | cmsg_01Q3o8RFpavsNskXDb46SG49DYyTdu2WEkToHfhPHoF5SN |
| 204 | Gate bots shard 4 on stage 1013c7d1 | done | yes | 2026-11-08T07:12:33Z | cmsg_01Q3o8RFpavsNskXDb46SG49BE3X6Z2zSy97YMXKehf1J8 |
| 205 | Gate bots shard 1 on stage 1013c7d1 | done | yes | 2026-11-08T07:07:46Z | cmsg_01Q3o8RFpavsNskXDb46SG494yD3MGZmyEetDTTpMG5ovU |
| 206 | Gate bots shard 2 on stage 1013c7d1 | done | yes | 2026-11-08T07:05:34Z | cmsg_01Q3o8RFpavsNskXDb46SG49HiDXCmJp9ABVeYUg2kQYvy |
| 207 | Gate bots shard 3 on stage 1013c7d1 | done | yes | 2026-11-08T07:05:17Z | cmsg_01Q3o8RFpavsNskXDb46SG4999six1PiLDEitjgA7uVJDw |
| 208 | Gate tests 346-690 on stage 5c5f70f1 | done | yes | 2026-10-31T13:54:13Z | cmsg_01Q3o8RFpavsNskXDb46SG49VdPcRXJKYsmB3qsnQsSHqb |
| 209 | Gate bands chunk C on stage 5c5f70f1 | done | yes | 2026-10-31T13:03:19Z | cmsg_01Q3o8RFpavsNskXDb46SG49BAoqtEReVv7nXKacc6CgRv |
| 210 | Gate tests 691-1080 on stage 5c5f70f1 | done | yes | 2026-10-31T12:45:36Z | cmsg_01Q3o8RFpavsNskXDb46SG49WHVec6PeC2zoj3SjKrBvy7 |
| 211 | Gate bands chunk B on stage 5c5f70f1 | done | yes | 2026-10-31T11:56:37Z | cmsg_01Q3o8RFpavsNskXDb46SG49TyrTvzYYqaAKHhPr7pZpzD |
| 212 | Red-team wave 30 as a line-rider | done | yes | 2026-10-31T11:33:42Z | cmsg_01Q3o8RFpavsNskXDb46SG4996TXjoDiE8CsaZBBB68ak4 |
| 213 | Gate tests 1-345 on stage 5c5f70f1 | done | yes | 2026-10-31T11:12:23Z | cmsg_01Q3o8RFpavsNskXDb46SG49BoGhFvrJm56acs1Uykes1x |
| 214 | Gate bots shard 5 on stage 5c5f70f1 | done | yes | 2026-10-31T10:58:35Z | cmsg_01Q3o8RFpavsNskXDb46SG49TKLZfn1MChExVn2K76LWbp |
| 215 | Gate bands chunk A on stage 5c5f70f1 | done | yes | 2026-10-31T10:57:19Z | cmsg_01Q3o8RFpavsNskXDb46SG499J49AEZverfmqKzbLXsyS9 |
| 216 | Gate bots shard 4 on stage 5c5f70f1 | done | yes | 2026-10-31T10:52:23Z | cmsg_01Q3o8RFpavsNskXDb46SG494dncNCipooceAP8wZYwQGd |
| 217 | Gate bots shard 6 on stage 5c5f70f1 | done | yes | 2026-10-31T10:51:09Z | cmsg_01Q3o8RFpavsNskXDb46SG49MtqZdDnW9oT3DHt6JZ26pQ |
| 218 | Gate bots shard 2 on stage 5c5f70f1 | done | yes | 2026-10-31T10:43:53Z | cmsg_01Q3o8RFpavsNskXDb46SG495VHNpPifT6XMHzSNgA5KGR |
| 219 | Gate bots shard 3 on stage 5c5f70f1 | done | yes | 2026-10-31T10:22:23Z | cmsg_01Q3o8RFpavsNskXDb46SG49RRmJRXhyuWvf2PpuEHhmi6 |
| 220 | Gate bots shard 1 on stage 5c5f70f1 | done | yes | 2026-10-31T10:17:08Z | cmsg_01Q3o8RFpavsNskXDb46SG49Lsj4KHKVG7eb5H9RgMZS7z |
| 221 | Cut the flume tile attach frame hitch | done | yes | 2026-10-31T08:04:02Z | cmsg_01Q3o8RFpavsNskXDb46SG499guxCkuC6sD5TgR3WCnaPK |
| 222 | Fix clipping and overlapping models in world 1 | done | yes | 2026-10-31T05:34:39Z | cmsg_01Q3o8RFpavsNskXDb46SG4923kH9XCaRQVaFpGHSrCMjU |
| 223 | Gate bots shard 6 on stage ff9984e0 | done | yes | 2026-10-31T04:06:50Z | cmsg_01Q3o8RFpavsNskXDb46SG49H33DTb6XtUEQRVuDP7J7s6 |
| 224 | Gate bands chunk C on stage ff9984e0 | done | yes | 2026-10-31T04:02:28Z | cmsg_01Q3o8RFpavsNskXDb46SG49ENbSYTWm5Y91q4qYYBHZiW |
| 225 | Gate bands chunk B on stage ff9984e0 | done | yes | 2026-10-31T02:04:08Z | cmsg_01Q3o8RFpavsNskXDb46SG49CUVsLvNr184Nry95RnNmpM |
| 226 | Red-team wave 29 as a greedy player | done | yes | 2026-10-31T01:42:38Z | cmsg_01Q3o8RFpavsNskXDb46SG49TBbBkbddf7VGcAqrSdN2ee |
| 227 | Gate tests 691-1080 on stage ff9984e0 | done | yes | 2026-10-31T01:21:13Z | cmsg_01Q3o8RFpavsNskXDb46SG49U3bmPFz4X3EpWKSK23oGnc |
| 228 | Gate bands chunk A on stage ff9984e0 | done | yes | 2026-10-31T01:00:09Z | cmsg_01Q3o8RFpavsNskXDb46SG49Tjd2GFDGCr6UkXDWSTnBMv |
| 229 | Gate bots shard 5 on stage ff9984e0 | done | yes | 2026-10-31T00:51:37Z | cmsg_01Q3o8RFpavsNskXDb46SG49DcvAJjPHix78xepd3XLxvz |
| 230 | Gate tests 346-690 on stage ff9984e0 | done | yes | 2026-10-31T00:51:16Z | cmsg_01Q3o8RFpavsNskXDb46SG495qHXW5fSAXASFhf3W52rxF |
| 231 | Gate bots shard 4 on stage ff9984e0 | done | yes | 2026-10-31T00:37:39Z | cmsg_01Q3o8RFpavsNskXDb46SG49RrZMc3QHVeBTiHStAuLad2 |
| 232 | Gate tests 1-345 on stage ff9984e0 | done | yes | 2026-10-31T00:35:20Z | cmsg_01Q3o8RFpavsNskXDb46SG49HMfWXzuH5sP2tsrSMHv4dP |
| 233 | Gate bots shard 2 on stage ff9984e0 | done | yes | 2026-10-31T00:30:28Z | cmsg_01Q3o8RFpavsNskXDb46SG49RfbJRPs57kr4soAxdJBExJ |
| 234 | Remove invisible walls in flume and Brindle arena | review_ready | yes | 2026-10-31T00:27:38Z | cmsg_01Q3o8RFpavsNskXDb46SG49Ek84qDX6mXF9FSXfF445ms |
| 235 | Gate bots shard 1 on stage ff9984e0 | done | yes | 2026-10-31T00:25:11Z | cmsg_01Q3o8RFpavsNskXDb46SG49BZaRDSY3cFCBUwBeD6xvpf |
| 236 | Gate bots shard 3 on stage ff9984e0 | done | yes | 2026-10-31T00:19:19Z | cmsg_01Q3o8RFpavsNskXDb46SG49GiS7a4ofAAUw3u7uhGDQ1n |
| 237 | Remove invisible walls in dam and camp | done | yes | 2026-10-30T22:41:48Z | cmsg_01Q3o8RFpavsNskXDb46SG495kH1VhHYzs1vJwcnXMcWEh |
| 238 | Bot gameplay QA of every world 1 spot | done | yes | 2026-10-30T22:41:27Z | cmsg_01Q3o8RFpavsNskXDb46SG49GS5UMwC7tP3Pu3QqUinMsY |
| 239 | Explorer bot shard C for world 1 QA | done | yes | 2026-10-30T20:00:01Z | cmsg_01Q3o8RFpavsNskXDb46SG49NHs2hAYDBgPCXdQUeFvvEi |
| 240 | Explorer bot shard B for world 1 QA | done | yes | 2026-10-30T19:58:08Z | cmsg_01Q3o8RFpavsNskXDb46SG49L4Z8bcrjZBCX5gEPXDASdX |
| 241 | Explorer bot shard A for world 1 QA | done | yes | 2026-10-30T19:55:34Z | cmsg_01Q3o8RFpavsNskXDb46SG49SHN5hUSVKpNeBxHpKhf1Bu |
| 242 | Gate bots shard 6 on stage 814a53ad | done | yes | 2026-10-26T14:05:05Z | cmsg_01Q3o8RFpavsNskXDb46SG49QhjRmqysF1whHXDY1XrbC4 |
| 243 | Gate bands on stage e646632d | done | yes | 2026-10-28T02:24:10Z | cmsg_01Q3o8RFpavsNskXDb46SG49Jrto18eSHoJNtR2qVdABCu |
| 244 | Gate bots shard 5 on stage 3133895f | done | yes | 2026-10-29T10:16:38Z | cmsg_01Q3o8RFpavsNskXDb46SG49TjHBtWaWswuwz6DAddrFj7 |
| 245 | Tidy the library docs and repo | done | yes | 2026-10-29T20:42:22Z | cmsg_01Q3o8RFpavsNskXDb46SG49N9t5yo47GAyAdzjmgh7m9K |
| 246 | Prepare the world 1 sitting build | done | yes | 2026-10-29T19:18:46Z | cmsg_01Q3o8RFpavsNskXDb46SG497zT5QPMZSZVaupshYhY3G5 |
| 247 | Fix music thread crash on rest | done | yes | 2026-10-30T00:14:16Z | cmsg_01Q3o8RFpavsNskXDb46SG494EbhK5e7Y8vwSuwfoo1urg |
| 248 | Show the death cause on RUN OVER | done | yes | 2026-10-30T03:25:02Z | cmsg_01Q3o8RFpavsNskXDb46SG497uZ5sXCc4GQ4NRruqU1gw4 |
| 249 | Gate bands chunk C on stage 04882ad5 | done | yes | 2026-10-30T03:46:57Z | cmsg_01Q3o8RFpavsNskXDb46SG49PznbNzn55FpLFN5AikFyVv |
| 250 | Red-team wave 28 as a cautious player | done | yes | 2026-10-30T02:57:28Z | cmsg_01Q3o8RFpavsNskXDb46SG494BPYurfZbs1MHCTdJACSzz |
| 251 | Gate bands chunk B on stage 04882ad5 | done | yes | 2026-10-30T02:46:26Z | cmsg_01Q3o8RFpavsNskXDb46SG49DLZudUKCniVq7GJsnWxMFK |
| 252 | Gate tests 691-end on stage 04882ad5 | done | yes | 2026-10-30T02:31:35Z | cmsg_01Q3o8RFpavsNskXDb46SG49EzUfi38U7Gz1q22GWgDCKy |
| 253 | Gate bands chunk A on stage 04882ad5 | done | yes | 2026-10-30T02:26:02Z | cmsg_01Q3o8RFpavsNskXDb46SG49H8dmpDvhpWozPhKhfzimv7 |
| 254 | Gate bots shard 5 on stage 04882ad5 | done | yes | 2026-10-30T02:18:39Z | cmsg_01Q3o8RFpavsNskXDb46SG496MTE2RiRq5yrwdRxP73JiX |
| 255 | Gate tests 346-690 on stage 04882ad5 | done | yes | 2026-10-30T02:09:43Z | cmsg_01Q3o8RFpavsNskXDb46SG49D8WnefZCEvqVUpVZ2eyDuA |
| 256 | Gate tests 1-345 on stage 04882ad5 | done | yes | 2026-10-30T02:00:46Z | cmsg_01Q3o8RFpavsNskXDb46SG495PivKf9p7q5ooQMJBeTa3v |
| 257 | Gate bots shard 4 on stage 04882ad5 | done | yes | 2026-10-30T01:59:21Z | cmsg_01Q3o8RFpavsNskXDb46SG49GaXrfDkVdtic2ZogcpGT1U |
| 258 | Gate bots shard 2 on stage 04882ad5 | done | yes | 2026-10-30T01:51:29Z | cmsg_01Q3o8RFpavsNskXDb46SG497L2ckXBFEfi5ztajVfvnPL |
| 259 | Gate bots shard 1 on stage 04882ad5 | done | yes | 2026-10-30T01:48:50Z | cmsg_01Q3o8RFpavsNskXDb46SG49VUyXKrsPK3pEGDT9vqpJEN |
| 260 | Gate bots shard 6 on stage 04882ad5 | done | yes | 2026-10-30T01:45:05Z | cmsg_01Q3o8RFpavsNskXDb46SG49UeNMuHRK69b9U7itpp8vYb |
| 261 | Gate bots shard 3 on stage 04882ad5 | done | yes | 2026-10-30T01:38:14Z | cmsg_01Q3o8RFpavsNskXDb46SG49YUsUiL8QyUs6NJUpzZ69AE |
| 262 | Gate bands chunk C on stage 51951b33 | done | yes | 2026-10-30T00:53:04Z | cmsg_01Q3o8RFpavsNskXDb46SG492HkKSdSuTktxcAnobE2Rtf |
| 263 | Gate tests 691-1070 on stage 51951b33 | done | yes | 2026-10-29T23:45:36Z | cmsg_01Q3o8RFpavsNskXDb46SG498H1WpjJw88cKM8UXsTtPrK |
| 264 | Gate bands chunk B on stage 51951b33 | done | yes | 2026-10-29T23:43:49Z | cmsg_01Q3o8RFpavsNskXDb46SG498sLGA2ibS8wq3tGy2WfKHc |
| 265 | Gate bands chunk A on stage 51951b33 | done | yes | 2026-10-29T23:28:15Z | cmsg_01Q3o8RFpavsNskXDb46SG49V8iHTCSVcA8gfYuM4T1jyR |
| 266 | Gate bots shard 5 on stage 51951b33 | done | yes | 2026-10-29T23:24:10Z | cmsg_01Q3o8RFpavsNskXDb46SG497zXhfCF3ioqVN2TpcqMvTi |
| 267 | Gate tests 1-345 on stage 51951b33 | done | yes | 2026-10-29T23:23:13Z | cmsg_01Q3o8RFpavsNskXDb46SG49RzwNuqtXpjF3MEQF1jqPhJ |
| 268 | Gate tests 346-690 on stage 51951b33 | done | yes | 2026-10-29T23:14:35Z | cmsg_01Q3o8RFpavsNskXDb46SG49LJf7STZKkesGmZYxEr3Atk |
| 269 | Gate bots shard 4 on stage 51951b33 | done | yes | 2026-10-29T23:04:00Z | cmsg_01Q3o8RFpavsNskXDb46SG49UsEuDPa1Vwo4jmfNFZEPVY |
| 270 | Gate bots shard 2 on stage 51951b33 | done | yes | 2026-10-29T22:54:51Z | cmsg_01Q3o8RFpavsNskXDb46SG49ADkd5i5PyW7VMkymjBN3oa |
| 271 | Gate bots shard 1 on stage 51951b33 | done | yes | 2026-10-29T22:53:17Z | cmsg_01Q3o8RFpavsNskXDb46SG49RMvYcSLxjpDPYAMQrv3jjH |
| 272 | Gate bots shard 6 on stage 51951b33 | done | yes | 2026-10-29T22:48:40Z | cmsg_01Q3o8RFpavsNskXDb46SG492u8uotSoorGsvVihcK5oEs |
| 273 | Gate bots shard 3 on stage 51951b33 | done | yes | 2026-10-29T22:44:41Z | cmsg_01Q3o8RFpavsNskXDb46SG49UtQ1QQGxQMQayX5SMbyDCH |
| 274 | Red-team wave 27 as a first-timer | done | yes | 2026-10-29T22:30:28Z | cmsg_01Q3o8RFpavsNskXDb46SG493ST7cFAmkawg1p79ChxFwt |
| 275 | Tune world 1 difficulty and HARD ladder | done | yes | 2026-10-29T20:30:29Z | cmsg_01Q3o8RFpavsNskXDb46SG49BSxELUfGm2eiSXMYF3hmmk |
| 276 | Close the shop buy-sell cog loop | done | yes | 2026-10-29T20:29:20Z | cmsg_01Q3o8RFpavsNskXDb46SG49M6mCkvL45K8Qw1wT3zH733 |
| 277 | Gate bands chunk C on stage f724a6e6 | done | yes | 2026-10-29T19:13:21Z | cmsg_01Q3o8RFpavsNskXDb46SG49499G8rWVjrzETVceUqPV23 |
| 278 | Gate bands chunk B on stage f724a6e6 | done | yes | 2026-10-29T18:06:11Z | cmsg_01Q3o8RFpavsNskXDb46SG4994hhdRLdivdp5GeLTuxs5x |
| 279 | Gate tests 691-1070 on stage f724a6e6 | done | yes | 2026-10-29T18:03:13Z | cmsg_01Q3o8RFpavsNskXDb46SG491BNBFS6iE9dC6vVjA7Howe |
| 280 | Gate bands chunk A on stage f724a6e6 | done | yes | 2026-10-29T17:45:18Z | cmsg_01Q3o8RFpavsNskXDb46SG49SvTiey6JKb7g1pMd2XeBSQ |
| 281 | Gate bots shard 5 on stage f724a6e6 | done | yes | 2026-10-29T17:41:20Z | cmsg_01Q3o8RFpavsNskXDb46SG495WLwgAuc26KgpgvBojfpAR |
| 282 | Gate tests 1-345 on stage f724a6e6 | done | yes | 2026-10-29T17:38:00Z | cmsg_01Q3o8RFpavsNskXDb46SG49PWGuTzT6ym1qcN6mFfQuBq |
| 283 | Red-team wave 26 as a speedrunner | done | yes | 2026-10-29T17:34:53Z | cmsg_01Q3o8RFpavsNskXDb46SG49QAofUwBRDCoFYw4SgdixCW |
| 284 | Gate tests 346-690 on stage f724a6e6 | done | yes | 2026-10-29T17:26:15Z | cmsg_01Q3o8RFpavsNskXDb46SG49DDNVocW9P3RUKDJqh4bsuZ |
| 285 | Gate bots shard 4 on stage f724a6e6 | done | yes | 2026-10-29T17:23:53Z | cmsg_01Q3o8RFpavsNskXDb46SG49LgF3HDM8q4yZrSYRvPdFMq |
| 286 | Gate bots shard 2 on stage f724a6e6 | done | yes | 2026-10-29T17:21:55Z | cmsg_01Q3o8RFpavsNskXDb46SG49BtzwFSoZtCwN8WDwrJ5Zi1 |
| 287 | Gate bots shard 1 on stage f724a6e6 | done | yes | 2026-10-29T17:20:47Z | cmsg_01Q3o8RFpavsNskXDb46SG49CVsx1EjRZeZJUEnKeQGy9B |
| 288 | Gate bots shard 3 on stage f724a6e6 | done | yes | 2026-10-29T17:05:19Z | cmsg_01Q3o8RFpavsNskXDb46SG499MAUX1SvEPf1X7a9Kq1rtX |
| 289 | Gate bots shard 6 on stage f724a6e6 | done | yes | 2026-10-29T17:03:42Z | cmsg_01Q3o8RFpavsNskXDb46SG49T8jBcP4rtUJ3a813trEYXh |
| 290 | Build the cobalt item rung for world 1 | done | yes | 2026-10-29T16:25:31Z | cmsg_01Q3o8RFpavsNskXDb46SG494zGWvnpwEzGXhjK2KtAtkP |
| 291 | Gate bands chunk C on stage 3133895f | done | yes | 2026-10-29T11:33:56Z | cmsg_01Q3o8RFpavsNskXDb46SG49EJtisVGdJ9LBm711VLXC3U |
| 292 | Gate bots shard 3 on stage 3133895f | done | yes | 2026-10-29T10:41:08Z | cmsg_01Q3o8RFpavsNskXDb46SG49HTKvJ3FqXieyeDsuZ6Fa1s |
| 293 | Gate bands chunk B on stage 3133895f | done | yes | 2026-10-29T10:34:16Z | cmsg_01Q3o8RFpavsNskXDb46SG49VcXCHRtFHeUxT8sRzsqYqQ |
| 294 | Gate tests 691-1069 on stage 3133895f | done | yes | 2026-10-29T10:27:09Z | cmsg_01Q3o8RFpavsNskXDb46SG49RyUfqPtZyM5nqLAY5QyJZz |
| 295 | Gate bands chunk A on stage 3133895f | done | yes | 2026-10-29T10:19:11Z | cmsg_01Q3o8RFpavsNskXDb46SG49JJGw5FwkgYPbib8TDfNxkT |
| 296 | Gate tests 346-690 on stage 3133895f | done | yes | 2026-10-29T10:11:15Z | cmsg_01Q3o8RFpavsNskXDb46SG49CCK3qM5HvvkuSsKEEMaRPv |
| 297 | Red-team wave 25 as a line-rider | done | yes | 2026-10-29T10:00:57Z | cmsg_01Q3o8RFpavsNskXDb46SG49SLCkMoaAP6xyMGkmvgh1MV |
| 298 | Gate bots shard 4 on stage 3133895f | done | yes | 2026-10-29T09:45:22Z | cmsg_01Q3o8RFpavsNskXDb46SG498t6ohBVZWpb2ooBZC9d75C |
| 299 | Gate tests 1-345 on stage 3133895f | done | yes | 2026-10-29T09:41:25Z | cmsg_01Q3o8RFpavsNskXDb46SG49Y98g3Q8WLMCfXoEejuWhu2 |
| 300 | Gate bots shard 2 on stage 3133895f | done | yes | 2026-10-29T09:36:33Z | cmsg_01Q3o8RFpavsNskXDb46SG491Fti6zgQdkkVQB5kvnLWow |
| 301 | Gate bots shard 1 on stage 3133895f | done | yes | 2026-10-29T09:33:59Z | cmsg_01Q3o8RFpavsNskXDb46SG49Gf7MUKNoEA9Hva8n5D7J2u |
| 302 | Gate bots shard 6 on stage 3133895f | done | yes | 2026-10-29T09:28:16Z | cmsg_01Q3o8RFpavsNskXDb46SG49Mw5CNFm4AvbdiWsG3DY7yr |
| 303 | Gate tests 691-1067 on stage 792df5a1 | done | yes | 2026-10-29T08:27:39Z | cmsg_01Q3o8RFpavsNskXDb46SG49Lg4hU6yVANFvbmeRX6reLz |
| 304 | Gate bands chunk C on stage 792df5a1 | done | yes | 2026-10-29T07:45:51Z | cmsg_01Q3o8RFpavsNskXDb46SG497MGjYbCzVYiwtbHReXQ4Fn |
| 305 | Red-team wave 24 as a greedy player | done | yes | 2026-10-29T07:03:06Z | cmsg_01Q3o8RFpavsNskXDb46SG498ek61oEuL6vn7kHghtuffo |
| 306 | Gate bands chunk B on stage 792df5a1 | done | yes | 2026-10-29T06:43:19Z | cmsg_01Q3o8RFpavsNskXDb46SG491wc8TdofgQHnGbrzcc5HDZ |
| 307 | Gate tests 346-690 on stage 792df5a1 | done | yes | 2026-10-29T06:34:27Z | cmsg_01Q3o8RFpavsNskXDb46SG49Vkou6FEPTC5GiUWRNQZCSN |
| 308 | Gate bands chunk A on stage 792df5a1 | done | yes | 2026-10-29T06:24:36Z | cmsg_01Q3o8RFpavsNskXDb46SG49DxdBXPAEdwywu6nmQJAHTK |
| 309 | Gate bots shard 5 on stage 792df5a1 | done | yes | 2026-10-29T06:15:27Z | cmsg_01Q3o8RFpavsNskXDb46SG49PHq3P8kDuqp2eky4pNzuFS |
| 310 | Gate bots shard 4 on stage 792df5a1 | done | yes | 2026-10-29T05:57:29Z | cmsg_01Q3o8RFpavsNskXDb46SG49Lk4WU3gHEdsNFtwYfQGV9e |
| 311 | Gate tests 1-345 on stage 792df5a1 | done | yes | 2026-10-29T05:52:27Z | cmsg_01Q3o8RFpavsNskXDb46SG49Aj5bwHxA7MuTtMQ8VC6Gpn |
| 312 | Gate bots shard 1 on stage 792df5a1 | done | yes | 2026-10-29T05:47:17Z | cmsg_01Q3o8RFpavsNskXDb46SG496NBtXz7GBHtLQ2YUSC9nEw |
| 313 | Gate bots shard 2 on stage 792df5a1 | done | yes | 2026-10-29T05:47:08Z | cmsg_01Q3o8RFpavsNskXDb46SG49CaReCvMaa1acC1d5i2vRUE |
| 314 | Gate bots shard 3 on stage 792df5a1 | done | yes | 2026-10-29T05:40:49Z | cmsg_01Q3o8RFpavsNskXDb46SG49Ta8BrSNvSD2qC3RLXJrZMK |
| 315 | Gate bots shard 6 on stage 792df5a1 | done | yes | 2026-10-29T05:39:44Z | cmsg_01Q3o8RFpavsNskXDb46SG49BF9ywoBKHkZDTnAmtmh6zW |
| 316 | Re-read world 1 pacing for the sitting | done | yes | 2026-10-29T00:39:06Z | cmsg_01Q3o8RFpavsNskXDb46SG49AcRy5PzkcXVMcfoK9GjCcX |
| 317 | Fit world 1 run pacing to budget | done | yes | 2026-10-29T00:35:03Z | cmsg_01Q3o8RFpavsNskXDb46SG49FHepXJ2tMUMuksyfqS3Pnx |
| 318 | Fix world 1 lock and menu edges | done | yes | 2026-10-29T00:13:50Z | cmsg_01Q3o8RFpavsNskXDb46SG49GeV9hr2U1iJYug6M9Y3sUr |
| 319 | Teach first-run players the dunk and HARD | done | yes | 2026-10-28T23:32:19Z | cmsg_01Q3o8RFpavsNskXDb46SG49UkrGtwtrx5CG4akjz1wF3y |
| 320 | Fix world 1 edge and boundary bugs | done | yes | 2026-10-28T22:27:45Z | cmsg_01Q3o8RFpavsNskXDb46SG498aqCS7Cxsn7s8wRCQF5gLX |
| 321 | Gate bands chunk C on stage 74f5cff5 | done | yes | 2026-10-28T21:56:24Z | cmsg_01Q3o8RFpavsNskXDb46SG49Mjqg7Sx1vx1gMSwdni2uoK |
| 322 | Red-team wave 23 as a cautious player | done | yes | 2026-10-28T21:20:35Z | cmsg_01Q3o8RFpavsNskXDb46SG494L76ZsR2gsEXeNWArnLepa |
| 323 | Gate tests 691-end on stage 74f5cff5 | done | yes | 2026-10-28T21:15:16Z | cmsg_01Q3o8RFpavsNskXDb46SG49WbtECgTS11RS2kpAsVB6iH |
| 324 | Gate tests 346-690 on stage 74f5cff5 | done | yes | 2026-10-28T20:51:53Z | cmsg_01Q3o8RFpavsNskXDb46SG49QoMGvfRLtAnwP5jrzWv7Gp |
| 325 | Gate bands chunk B on stage 74f5cff5 | done | yes | 2026-10-28T20:37:59Z | cmsg_01Q3o8RFpavsNskXDb46SG49SWcP3TQJiiACejUkYWYxAC |
| 326 | Gate tests 1-345 on stage 74f5cff5 | done | yes | 2026-10-28T20:33:16Z | cmsg_01Q3o8RFpavsNskXDb46SG49PZUSWzdXEBk6B25LP9NCLY |
| 327 | Gate bands chunk A on stage 74f5cff5 | done | yes | 2026-10-28T20:27:34Z | cmsg_01Q3o8RFpavsNskXDb46SG494kUDTSkDAxDqByy2RSBE3y |
| 328 | Gate bots shard 5 on stage 74f5cff5 | done | yes | 2026-10-28T20:17:56Z | cmsg_01Q3o8RFpavsNskXDb46SG49CE7DKJxotVjDDArEX6fMXf |
| 329 | Gate bots shard 4 on stage 74f5cff5 | done | yes | 2026-10-28T20:05:22Z | cmsg_01Q3o8RFpavsNskXDb46SG49J4LtuvVcBLzte824Rw2tBB |
| 330 | Gate bots shard 2 on stage 74f5cff5 | done | yes | 2026-10-28T19:49:24Z | cmsg_01Q3o8RFpavsNskXDb46SG49SnVHTgyxq6CjuGRSnWQE1j |
| 331 | Gate bots shard 3 on stage 74f5cff5 | done | yes | 2026-10-28T19:45:19Z | cmsg_01Q3o8RFpavsNskXDb46SG49AfC9tt2CBDc4d28QHDPowD |
| 332 | Gate bots shard 1 on stage 74f5cff5 | done | yes | 2026-10-28T19:44:18Z | cmsg_01Q3o8RFpavsNskXDb46SG49491MkUyad2mkyvYJquitKKa2 |
| 333 | Gate bots shard 6 on stage 74f5cff5 | done | yes | 2026-10-28T19:41:18Z | cmsg_01Q3o8RFpavsNskXDb46SG49VgvbmH5uyUwc7sX5JQgh8p |
| 334 | Gate bands chunk C on stage 81c42290 | done | yes | 2026-10-28T18:24:05Z | cmsg_01Q3o8RFpavsNskXDb46SG49PPB7QXnCxtAxFqggNz4Mkp |
| 335 | Gate tests 691-end on stage 81c42290 | done | yes | 2026-10-28T18:23:46Z | cmsg_01Q3o8RFpavsNskXDb46SG49LC2thbqJbMhuuANSYoLB4W |
| 336 | Gate tests 346-690 on stage 81c42290 | done | yes | 2026-10-28T17:19:18Z | cmsg_01Q3o8RFpavsNskXDb46SG49495WeMg5RXkMJ1EjXuA5HtAq |
| 337 | Gate bands chunk B on stage 81c42290 | done | yes | 2026-10-28T17:14:47Z | cmsg_01Q3o8RFpavsNskXDb46SG49C2y8G22Xsmo7Xpst476efD |
| 338 | Gate bands chunk B on stage 81c42290 | done | yes | 2026-10-28T17:14:09Z | cmsg_01Q3o8RFpavsNskXDb46SG49PhQCBqRgo845AohtnbX3AL |
| 339 | Gate bands chunk A on stage 81c42290 | done | yes | 2026-10-28T16:59:47Z | cmsg_01Q3o8RFpavsNskXDb46SG49VMK9k3xrYJ1ymaeN4ysjWo |
| 340 | Gate tests 1-345 on stage 81c42290 | done | yes | 2026-10-28T16:58:53Z | cmsg_01Q3o8RFpavsNskXDb46SG49JC5RQkoMKz77Mj8SNHnsUV |
| 341 | Gate bots shard 2 on stage 81c42290 | done | yes | 2026-10-28T16:55:21Z | cmsg_01Q3o8RFpavsNskXDb46SG49KPyE8Fn1bgJu2e92DzTpit |
| 342 | Gate bots shard 5 on stage 81c42290 | done | yes | 2026-10-28T16:51:48Z | cmsg_01Q3o8RFpavsNskXDb46SG49UXdmAs1MB26sfJ1uX9A5cH |
| 343 | Fix world 1's last frame hitches | done | yes | 2026-10-28T16:30:16Z | cmsg_01Q3o8RFpavsNskXDb46SG49DtjFFLJMdf9qFnRfvipaj2 |
| 344 | Gate bots shard 4 on stage 81c42290 | done | yes | 2026-10-28T16:26:53Z | cmsg_01Q3o8RFpavsNskXDb46SG49WGmLD8fhuK7jsGCNojh3ub |
| 345 | Gate bots shard 1 on stage 81c42290 | done | yes | 2026-10-28T16:14:43Z | cmsg_01Q3o8RFpavsNskXDb46SG49Ri75C2Sqab1f5n6bEvaNx2 |
| 346 | Gate bots shard 6 on stage 81c42290 | done | yes | 2026-10-28T16:08:16Z | cmsg_01Q3o8RFpavsNskXDb46SG49MafKbHuVV1oBy2vKtvCi9y |
| 347 | Gate bots shard 3 on stage 81c42290 | done | yes | 2026-10-28T16:07:04Z | cmsg_01Q3o8RFpavsNskXDb46SG49WCuKGjBwLAzM1zU6GffQaX |
| 348 | Red-team wave 22 as a first-timer | done | yes | 2026-10-28T15:53:16Z | cmsg_01Q3o8RFpavsNskXDb46SG498FXmKA7sT5YWmwLyvNDc3y |
| 349 | Gate bands chunk C on stage bf3d2722 | done | yes | 2026-10-28T15:07:46Z | cmsg_01Q3o8RFpavsNskXDb46SG49X33J1xpNanrYrEqSaWjoE4 |
| 350 | Gate tests 346-690 on stage bf3d2722 | done | yes | 2026-10-28T14:35:36Z | cmsg_01Q3o8RFpavsNskXDb46SG49DrFz7d7w5eiyrTYD9cWUG9 |
| 351 | Gate tests 691-end on stage bf3d2722 | done | yes | 2026-10-28T14:25:15Z | cmsg_01Q3o8RFpavsNskXDb46SG492vtbPkp2d57NtepEMLQntz |
| 352 | Gate bands chunk B on stage bf3d2722 | done | yes | 2026-10-28T14:05:56Z | cmsg_01Q3o8RFpavsNskXDb46SG49QDNAdCaPrLTLmBHpzdCnuT |
| 353 | Gate bands chunk A on stage bf3d2722 | done | yes | 2026-10-28T13:52:59Z | cmsg_01Q3o8RFpavsNskXDb46SG496dNr9QFg3MqqkxF1yLS8vQ |
| 354 | Gate tests 1-345 on stage bf3d2722 | done | yes | 2026-10-28T13:38:42Z | cmsg_01Q3o8RFpavsNskXDb46SG49SYdVnM8ZYX3XqQuUo2kAgN |
| 355 | Gate bots shard 3 on stage bf3d2722 | done | yes | 2026-10-28T13:36:43Z | cmsg_01Q3o8RFpavsNskXDb46SG49M58tfCQePrBpWu2Vt7sZtx |
| 356 | Gate bots shard 5 on stage bf3d2722 | done | yes | 2026-10-28T13:33:40Z | cmsg_01Q3o8RFpavsNskXDb46SG49TELdXD5cn4Pz1BxbamBmL7 |
| 357 | Red-team wave 21 as a speedrunner | done | yes | 2026-10-28T13:24:30Z | cmsg_01Q3o8RFpavsNskXDb46SG49DY5ZF6iheGYXvAryHLyRCr |
| 358 | Gate bots shard 4 on stage bf3d2722 | done | yes | 2026-10-28T13:17:12Z | cmsg_01Q3o8RFpavsNskXDb46SG49EwNQjy7jfti5N2pwWnhLv1 |
| 359 | Gate bots shard 1 on stage bf3d2722 | done | yes | 2026-10-28T13:02:00Z | cmsg_01Q3o8RFpavsNskXDb46SG4919btdmo4TY99xAot5pZZ6X |
| 360 | Gate bots shard 2 on stage bf3d2722 | done | yes | 2026-10-28T13:00:49Z | cmsg_01Q3o8RFpavsNskXDb46SG49R23HS8GHGAnEUxkchoCbS5 |
| 361 | Gate bots shard 6 on stage bf3d2722 | done | yes | 2026-10-28T12:56:02Z | cmsg_01Q3o8RFpavsNskXDb46SG49M7j6Su9M5CMEgymzCoqYvn |
| 362 | Fix run_tier and frame-split test flakes | done | yes | 2026-10-28T02:10:37Z | cmsg_01Q3o8RFpavsNskXDb46SG49MYWP4QXvJY5tfiZFFHWVwx |
| 363 | Gate bots shard 5 on stage e646632d | done | yes | 2026-10-28T01:48:36Z | cmsg_01Q3o8RFpavsNskXDb46SG49QDoV2LUHiXb6Dnun1Vp47p |
| 364 | Gate tests 691-1057 on stage e646632d | done | yes | 2026-10-28T01:14:46Z | cmsg_01Q3o8RFpavsNskXDb46SG49Row3RgESPqCF3QrCmniSfp |
| 365 | Gate tests 346-690 on stage e646632d | done | yes | 2026-10-28T00:44:13Z | cmsg_01Q3o8RFpavsNskXDb46SG49VZZrzzGKYJk3X7tyJADhzM |
| 366 | Gate bots shard 1 on stage e646632d | done | yes | 2026-10-27T23:46:02Z | cmsg_01Q3o8RFpavsNskXDb46SG49GNh3PxWPX9oZPeGsaXfMcg |
| 367 | Gate bots shard 2 on stage e646632d | done | yes | 2026-10-27T23:39:58Z | cmsg_01Q3o8RFpavsNskXDb46SG49LvvKPtvhHeCYDYPjkzaTwf |
| 368 | Gate bands chunk A on stage c3abb730 | done | yes | 2026-10-27T23:20:03Z | cmsg_01Q3o8RFpavsNskXDb46SG49L4oeEE3ZXpaFPyxLb5mWiv |
| 369 | Gate bands chunk C on stage c3abb730 | done | yes | 2026-10-27T23:19:00Z | cmsg_01Q3o8RFpavsNskXDb46SG49Ewz4wY6z5HZRdhTkarZFLr |
| 370 | Gate bands chunk B on stage c3abb730 | done | yes | 2026-10-27T23:18:53Z | cmsg_01Q3o8RFpavsNskXDb46SG49HWiagPDBSXkRzT1GC8Ss6m |
| 371 | Gate bots shard 1 on stage c3abb730 | done | yes | 2026-10-27T23:18:47Z | cmsg_01Q3o8RFpavsNskXDb46SG49PAsyuu5pQBJ8hm9pQULEhi |
| 372 | Gate bots shard 2 on stage c3abb730 | done | yes | 2026-10-27T23:18:25Z | cmsg_01Q3o8RFpavsNskXDb46SG494ajUer9NrMgtfuLiFf1qeQ |
| 373 | Gate bots shard 4 on stage e646632d | done | yes | 2026-10-27T21:47:04Z | cmsg_01Q3o8RFpavsNskXDb46SG493Utd2NPXbYjAUAwtvtJvXY |
| 374 | Red-team line-rider on stage e646632d | done | yes | 2026-10-27T21:05:02Z | cmsg_01Q3o8RFpavsNskXDb46SG49XscBcNKN4gv9sVvS3FHaKh |
| 375 | Gate bots shard 6 on stage e646632d | done | yes | 2026-10-27T20:43:42Z | cmsg_01Q3o8RFpavsNskXDb46SG49RAgrfPAERwZMARzyZ7xHo2 |
| 376 | Gate tests 1-345 on stage e646632d | done | yes | 2026-10-27T20:35:45Z | cmsg_01Q3o8RFpavsNskXDb46SG4985tDHfH2ZZB4EN9QVk2Gy5 |
| 377 | Fix music ring running dry at boot | done | yes | 2026-10-27T20:35:06Z | cmsg_01Q3o8RFpavsNskXDb46SG49JDoyYqV3Sjk19DVAAL35FH |
| 378 | Gate bots shard 3 on stage e646632d | done | yes | 2026-10-27T20:33:35Z | cmsg_01Q3o8RFpavsNskXDb46SG49Tugbej99RdWW9sJ9uTN4dP |
| 379 | Gate bands on stage f441455d | done | yes | 2026-10-27T09:15:05Z | cmsg_01Q3o8RFpavsNskXDb46SG49BXcTvra8VdLWEaU2McEk1k |
| 380 | Gate bots shard 5 on stage 6b16a2d2 | done | yes | 2026-10-27T07:47:58Z | cmsg_01Q3o8RFpavsNskXDb46SG49Fs56hzo3juedoZQkdpT1LW |
| 381 | Red team greedy on stage f441455d | done | yes | 2026-10-27T07:13:59Z | cmsg_01Q3o8RFpavsNskXDb46SG49PGTKATYDKUWt63wwrJzJVD |
| 382 | Gate tests 691-1053 on stage f441455d | done | yes | 2026-10-27T06:54:40Z | cmsg_01Q3o8RFpavsNskXDb46SG49RwEFJEXTujZoPchei2DoKx |
| 383 | Gate bots shard 6 on stage 6b16a2d2 | done | yes | 2026-10-27T06:48:09Z | cmsg_01Q3o8RFpavsNskXDb46SG49XpdoPpBMNxdE18hv2SayjF |
| 384 | Fix riser music reds from world 1 sounds | done | yes | 2026-10-27T06:46:22Z | cmsg_01Q3o8RFpavsNskXDb46SG49NYxMiKrwJCR1bfic2roNYt |
| 385 | Gate tests 346-690 on stage f441455d | done | yes | 2026-10-27T06:32:17Z | cmsg_01Q3o8RFpavsNskXDb46SG49CZNfyfBqqom2wUzUpmZJC2 |
| 386 | Gate bots shard 4 on stage f441455d | done | yes | 2026-10-27T05:39:06Z | cmsg_01Q3o8RFpavsNskXDb46SG49FyDYbr9yoyPFQQyFFso7YW |
| 387 | Gate tests 1-345 on stage f441455d | done | yes | 2026-10-27T05:23:48Z | cmsg_01Q3o8RFpavsNskXDb46SG49MEyYqtKvytK9fXGowyagfX |
| 388 | Gate bots shard 5 on stage f441455d | done | yes | 2026-10-27T05:08:50Z | cmsg_01Q3o8RFpavsNskXDb46SG494S1BnkX1CJwhxjFCPQ5XTq |
| 389 | Gate bots shard 1 on stage f441455d | done | yes | 2026-10-27T04:56:35Z | cmsg_01Q3o8RFpavsNskXDb46SG491MRUq6bkzG3TpeRZ3ChgEH |
| 390 | Gate bots shard 3 on stage f441455d | done | yes | 2026-10-27T04:34:23Z | cmsg_01Q3o8RFpavsNskXDb46SG49972rrdYCb1xBtAhEDF1Cfs |
| 391 | Gate bots shard 2 on stage f441455d | done | yes | 2026-10-27T04:30:47Z | cmsg_01Q3o8RFpavsNskXDb46SG4917c96Nkb9kJk2dZ7kU9Rg2 |
| 392 | Gate bots shard 6 on stage f441455d | done | yes | 2026-10-27T04:29:03Z | cmsg_01Q3o8RFpavsNskXDb46SG49NJaJ2XfjF71U3QXEN58dZr |
| 393 | Place world 1 park rewards on reachable ground | done | yes | 2026-10-27T03:34:19Z | cmsg_01Q3o8RFpavsNskXDb46SG49UvNHhnBENABKfbSQZn5EC6 |
| 394 | Fix warning ring contrast on noon floor | done | yes | 2026-10-27T03:11:51Z | cmsg_01Q3o8RFpavsNskXDb46SG49JHz8txyU3q8EXeUBJu6m7e |
| 395 | Rehome the dam radio find | done | yes | 2026-10-27T03:11:39Z | cmsg_01Q3o8RFpavsNskXDb46SG49CsWJdEANSDNKdEuZJzwxWv |
| 396 | Gate band reads on stage b9c07752 | done | yes | 2026-10-27T03:11:27Z | cmsg_01Q3o8RFpavsNskXDb46SG49LPT5BnLDQYxTiNEvcWmZUd |
| 397 | Gate bots shard 5 on stage b9c07752 | done | yes | 2026-10-27T03:11:22Z | cmsg_01Q3o8RFpavsNskXDb46SG49EhRk421ExzhH5NeSTNb5Qb |
| 398 | Gate tests 346-690 on stage b9c07752 | done | yes | 2026-10-27T03:11:16Z | cmsg_01Q3o8RFpavsNskXDb46SG49Efa1BPeAvDfjZrGa9qM36T |
| 399 | Gate bots shard 3 on stage b9c07752 | done | yes | 2026-10-27T03:11:15Z | cmsg_01Q3o8RFpavsNskXDb46SG49RLF99AP7SW6p8JsQVB2Nq5 |
| 400 | Gate bots shard 1 on stage b9c07752 | done | yes | 2026-10-27T03:11:00Z | cmsg_01Q3o8RFpavsNskXDb46SG49Bauu8LGcDa2mrkrVYYyRkS |
| 401 | Gate tests 691-1049 on stage b9c07752 | done | yes | 2026-10-26T23:31:04Z | cmsg_01Q3o8RFpavsNskXDb46SG49Fiv8yPZp56udH7WBVgitUH |
| 402 | Red team cautious on stage b9c07752 | done | yes | 2026-10-26T23:10:39Z | cmsg_01Q3o8RFpavsNskXDb46SG49YZ4SnNEcX7nz3aLtMGgmxE |
| 403 | Gate tests 1-345 on stage b9c07752 | done | yes | 2026-10-26T22:57:42Z | cmsg_01Q3o8RFpavsNskXDb46SG49EzQhPyNAoAywXBHB8yQoWc |
| 404 | Gate bots shard 4 on stage b9c07752 | done | yes | 2026-10-26T22:41:28Z | cmsg_01Q3o8RFpavsNskXDb46SG49CFUj2GBNs2e2ByzJsz3CnE |
| 405 | Gate bots shard 6 on stage b9c07752 | done | yes | 2026-10-26T22:04:40Z | cmsg_01Q3o8RFpavsNskXDb46SG49JqDU6KFabW1NBGpUaNaKhB |
| 406 | Gate bots shard 2 on stage b9c07752 | done | yes | 2026-10-26T21:56:20Z | cmsg_01Q3o8RFpavsNskXDb46SG49Sah5DY6WYnRMZKs2sGcNed |
| 407 | Finish dam park edge | done | yes | 2026-10-26T17:28:45Z | cmsg_01Q3o8RFpavsNskXDb46SG49SbY3CzoaDnZdrZZAn9KUoW |
| 408 | Gate band reads on stage 814a53ad | done | yes | 2026-10-26T17:12:24Z | cmsg_01Q3o8RFpavsNskXDb46SG4931EDyMjCqHGYPBB7BETAQg |
| 409 | Red-team probe of moved radio find | done | yes | 2026-10-26T16:35:01Z | cmsg_01Q3o8RFpavsNskXDb46SG49F453nWSZNQihEuxBNBU3RG |
| 410 | Gate tests 691-end on stage 814a53ad | done | yes | 2026-10-26T16:33:36Z | cmsg_01Q3o8RFpavsNskXDb46SG492facuSyXwoGUfMawPZ8cBB |
| 411 | Gate tests 346-690 on stage 814a53ad | done | yes | 2026-10-26T15:26:26Z | cmsg_01Q3o8RFpavsNskXDb46SG49UirD4FwgNGbPGp9kS9xebe |
| 412 | Gate bots shard 4 on stage 814a53ad | done | yes | 2026-10-26T14:55:39Z | cmsg_01Q3o8RFpavsNskXDb46SG49HgajsE2zCjaa2sHYCoSZT9 |
| 413 | Gate tests 1-345 on stage 814a53ad | done | yes | 2026-10-26T14:36:39Z | cmsg_01Q3o8RFpavsNskXDb46SG494revBh8mCYPLNvUXQhNXCR |
| 414 | Gate bots shard 5 on stage 814a53ad | done | yes | 2026-10-26T14:35:04Z | cmsg_01Q3o8RFpavsNskXDb46SG492HqA2hn9zCHBFV6CCZ9ehm |
| 415 | Gate bots shard 2 on stage 814a53ad | done | yes | 2026-10-26T14:05:40Z | cmsg_01Q3o8RFpavsNskXDb46SG496XNF4FZhx2hhTbFS7uAsYE |
| 416 | Red-team stage 814a53ad before promotion | done | yes | 2026-10-26T13:36:20Z | cmsg_01Q3o8RFpavsNskXDb46SG49Xz7bkgRMxX4vTvBgETnite |
| 417 | Gate bots shard 1 on stage 814a53ad | done | yes | 2026-10-26T13:35:07Z | cmsg_01Q3o8RFpavsNskXDb46SG498VGeKVt8sWVB2DJo4m6cVR |
| 418 | Gate bots shard 3 on stage 814a53ad | done | yes | 2026-10-26T13:34:32Z | cmsg_01Q3o8RFpavsNskXDb46SG494q6iCgEk71FWJ28dHhu1d4 |
| 419 | Prove dam rogue site gets played | done | yes | 2026-10-26T12:37:52Z | cmsg_01Q3o8RFpavsNskXDb46SG498SxWAQTX5q4D6Qaikzfi77 |
| 420 | Gate band reads on stage 1d2b593a | done | yes | 2026-10-26T12:35:05Z | cmsg_01Q3o8RFpavsNskXDb46SG49AaPSsQ9F7kEBStuVALtpyn |
| 421 | Gate bots shard 5 on stage 1d2b593a | done | yes | 2026-10-26T12:18:00Z | cmsg_01Q3o8RFpavsNskXDb46SG491PZDdLuejCEJRUrnnYSdoT |
| 422 | Gate tests 691-end on stage 1d2b593a | done | yes | 2026-10-26T12:11:19Z | cmsg_01Q3o8RFpavsNskXDb46SG49TL3Y8T8HntAMbTPS99Lc45 |
| 423 | Gate tests 346-690 on stage 1d2b593a | done | yes | 2026-10-26T11:25:09Z | cmsg_01Q3o8RFpavsNskXDb46SG49XHZVH8VsCDbVA3jVqQ2fda |
| 424 | Gate bots shard 6 on stage 1d2b593a | done | yes | 2026-10-26T11:23:48Z | cmsg_01Q3o8RFpavsNskXDb46SG492PCVca1p1gPM1PWqV7n4pb |
| 425 | Gate tests 1-345 on stage 1d2b593a | done | yes | 2026-10-26T11:18:18Z | cmsg_01Q3o8RFpavsNskXDb46SG496yJMAgnS44DgeYRQUmokG5 |
| 426 | Gate bots shard 4 on stage 1d2b593a | done | yes | 2026-10-26T11:07:51Z | cmsg_01Q3o8RFpavsNskXDb46SG499z3tGqcVaFKc2128gv7EV5 |
| 427 | Gate bots shard 2 on stage 1d2b593a | done | yes | 2026-10-26T10:59:58Z | cmsg_01Q3o8RFpavsNskXDb46SG49JQ1kUFsvfrGAsBiLManAtZ |
| 428 | Gate bots shard 3 on stage 1d2b593a | done | yes | 2026-10-26T10:52:29Z | cmsg_01Q3o8RFpavsNskXDb46SG4971MkJ6vC8furgvs9mHLTDP |
| 429 | Close pack pressure experiments on world 1 | done | yes | 2026-10-26T10:37:41Z | cmsg_01Q3o8RFpavsNskXDb46SG495GpZTzkjwQcR7QKjCKvocG |
| 430 | Learner band shard boils off 4 of 4 | done | yes | 2026-10-26T10:01:01Z | cmsg_01Q3o8RFpavsNskXDb46SG49UXtiTgEZ8RH2ypd7rEWs4Q |
| 431 | Learner band shard boils off 2 of 4 | done | yes | 2026-10-26T10:13:05Z | cmsg_01Q3o8RFpavsNskXDb46SG49Ep6CDxUJFfH54B5sh9c2Vt |
| 432 | Learner band shard boils on 3 of 4 | done | yes | 2026-10-26T09:48:12Z | cmsg_01Q3o8RFpavsNskXDb46SG49DSb6GWEzyGVU3PEHz67Bao |
| 433 | Learner band shard boils on 1 of 4 | done | yes | 2026-10-26T10:36:04Z | cmsg_01Q3o8RFpavsNskXDb46SG49AJnkfBpCpNkGcjhnd3zxV4 |
| 434 | Gate bots shard 1 on stage 1d2b593a | done | yes | 2026-10-26T10:34:21Z | cmsg_01Q3o8RFpavsNskXDb46SG494bgn6CVaAahYJMmFmx8kXJ |
| 435 | Learner band shard boils off 3 of 4 | done | yes | 2026-10-26T10:30:31Z | cmsg_01Q3o8RFpavsNskXDb46SG492j1FbL2HZvYMYoWTeKQjef |
| 436 | Red-team stage 1d2b593a before promotion | done | yes | 2026-10-26T10:29:46Z | cmsg_01Q3o8RFpavsNskXDb46SG49Xk511xxNi2iiNHbvnmg82a |
| 437 | Learner band shard boils on 2 of 4 | done | yes | 2026-10-26T10:12:08Z | cmsg_01Q3o8RFpavsNskXDb46SG49LN6szNMDHBu1rr9DkFQuuU |
| 438 | Learner band shard boils off 1 of 4 | done | yes | 2026-10-26T10:05:18Z | cmsg_01Q3o8RFpavsNskXDb46SG49HsXtnsExVzkBVqo6QXGdr5 |
| 439 | Learner band shard boils on 4 of 4 | done | yes | 2026-10-26T10:01:58Z | cmsg_01Q3o8RFpavsNskXDb46SG49BM6mppbuELc87sBTdc3AKu |
| 440 | Finish world 1 day-cycle rows | done | yes | 2026-10-26T09:44:51Z | cmsg_01Q3o8RFpavsNskXDb46SG49WwwgziscjQKsKM6yqyDe3i |
| 441 | Finish Brindle phase ratchet lane | done | yes | 2026-10-26T09:44:37Z | cmsg_01Q3o8RFpavsNskXDb46SG49PxerSDLuUTHFzwrMmQ4hm9 |
| 442 | Gate tests 1-345 on stage 0e2bc2f0 | done | yes | 2026-10-26T09:29:43Z | cmsg_01Q3o8RFpavsNskXDb46SG49KUHjHU14RtaoHG7ZhJfmVs |
| 443 | Gate tests 691-end on stage 0e2bc2f0 | done | yes | 2026-10-26T09:06:50Z | cmsg_01Q3o8RFpavsNskXDb46SG49R5SbnKkCb21LqVU9wXFQ21 |
| 444 | Gate band reads on stage 0e2bc2f0 | done | yes | 2026-10-26T08:41:20Z | cmsg_01Q3o8RFpavsNskXDb46SG49PUxHhJNyMDNSMxs74JTWqE |
| 445 | Gate tests 346-690 on stage 0e2bc2f0 | done | yes | 2026-10-26T08:27:30Z | cmsg_01Q3o8RFpavsNskXDb46SG49NQo1ma6TDzaPyipReAX8uV |
| 446 | Red-team stage 0e2bc2f0 before promotion | done | yes | 2026-10-26T08:20:04Z | cmsg_01Q3o8RFpavsNskXDb46SG49KBeLwHkRoXeZPMBZpVLaAE |
| 447 | Gate bots shard 5 on stage 0e2bc2f0 | done | yes | 2026-10-26T07:55:45Z | cmsg_01Q3o8RFpavsNskXDb46SG497p2Q2JLZQHEFWM93WAzQfa |
| 448 | Gate bots shard 1 on stage 0e2bc2f0 | done | yes | 2026-10-26T07:48:28Z | cmsg_01Q3o8RFpavsNskXDb46SG49V6APm5bHJrY6vVRKxLMhSj |
| 449 | Gate bots shard 4 on stage 0e2bc2f0 | done | yes | 2026-10-26T07:44:11Z | cmsg_01Q3o8RFpavsNskXDb46SG49QzVn53XhgYLQm1enq5aNc1 |
| 450 | Gate bots shard 2 on stage 0e2bc2f0 | done | yes | 2026-10-26T07:35:56Z | cmsg_01Q3o8RFpavsNskXDb46SG49N66azTkEXB3anc3vM8JXCa |
| 451 | Gate bots shard 6 on stage 0e2bc2f0 | done | yes | 2026-10-26T07:34:10Z | cmsg_01Q3o8RFpavsNskXDb46SG49EPvMCnG2gDyGiGitkwq7by |
| 452 | Gate bots shard 3 on stage 0e2bc2f0 | done | yes | 2026-10-26T07:21:00Z | cmsg_01Q3o8RFpavsNskXDb46SG497CUgPYWe2F7e2igYY6q9jy |
| 453 | Fix rogue kill count and cache panel height | done | yes | 2026-10-26T05:04:50Z | cmsg_01Q3o8RFpavsNskXDb46SG497N5qQMfuoDLDVYsqW3gLjJ |
| 454 | Red-team stage f7af1604 before promotion | done | yes | 2026-10-26T04:19:29Z | cmsg_01Q3o8RFpavsNskXDb46SG497zjXcFNbyjbXVx3xrejDPn |
| 455 | Gate tests 691-end on stage f7af1604 | done | yes | 2026-10-26T03:40:52Z | cmsg_01Q3o8RFpavsNskXDb46SG49QFXQKn1UNRfDcqEdz6MwU4 |
| 456 | Gate band reads on stage f7af1604 | done | yes | 2026-10-26T03:15:46Z | cmsg_01Q3o8RFpavsNskXDb46SG49UYaHm4yhVPT5YhM249LQNA |
| 457 | Gate bots shard 5 on stage f7af1604 | done | yes | 2026-10-26T02:50:11Z | cmsg_01Q3o8RFpavsNskXDb46SG49Qz4pqgcxbhUnpLqCyLZRkG |
| 458 | Gate bots shard 4 on stage f7af1604 | done | yes | 2026-10-26T02:47:00Z | cmsg_01Q3o8RFpavsNskXDb46SG49Vnuw2oUgi56o7JRfP6LvfV |
| 459 | Gate tests 346-690 on stage f7af1604 | done | yes | 2026-10-26T02:43:11Z | cmsg_01Q3o8RFpavsNskXDb46SG49MU5HB2FNm3hXMxbKVP59vx |
| 460 | Gate tests 1-345 on stage f7af1604 | done | yes | 2026-10-26T02:38:39Z | cmsg_01Q3o8RFpavsNskXDb46SG49JZu7NxHw8T8S6dd339imRC |
| 461 | Gate bots shard 3 on stage f7af1604 | done | yes | 2026-10-26T02:20:05Z | cmsg_01Q3o8RFpavsNskXDb46SG49FwBuEDv7Yg5VTPBSoRppuz |
| 462 | Gate bots shard 1 on stage f7af1604 | done | yes | 2026-10-26T02:18:57Z | cmsg_01Q3o8RFpavsNskXDb46SG49XZxVfBhNAXrhtWj2cRPDB4 |
| 463 | Gate bots shard 2 on stage f7af1604 | done | yes | 2026-10-26T02:18:52Z | cmsg_01Q3o8RFpavsNskXDb46SG49R8n8pcPzx2qwjFYq5xEksz |
| 464 | Gate bots shard 6 on stage f7af1604 | done | yes | 2026-10-26T01:51:38Z | cmsg_01Q3o8RFpavsNskXDb46SG49P16ESf24DbAcBab9JT3oia |
| 465 | Prove flume rogue and rib caches get played | done | yes | 2026-10-26T00:36:34Z | cmsg_01Q3o8RFpavsNskXDb46SG49HByi3ZXqerBZPU3fkfXD6c |
| 466 | Fix skipper stall at flume ledge | done | yes | 2026-10-26T00:28:05Z | cmsg_01Q3o8RFpavsNskXDb46SG49J8hVoEah4CvStmfpqj3VfU |
| 467 | Gate bots shard 5 on stage 49bf68c7 | done | yes | 2026-10-25T18:35:16Z | cmsg_01Q3o8RFpavsNskXDb46SG499KAxVqxkJFYPfhxQVacPjU |
| 468 | Gate tests 346-690 on stage 49bf68c7 | done | yes | 2026-10-25T18:05:13Z | cmsg_01Q3o8RFpavsNskXDb46SG49AASNPycWBzB1Eu7BcWdFZe |
| 469 | Gate bots shard 6 on stage 49bf68c7 | done | yes | 2026-10-25T17:44:28Z | cmsg_01Q3o8RFpavsNskXDb46SG496cBxpkF8yctezzXLsVDATa |
| 470 | Gate band reads on stage 49bf68c7 | done | yes | 2026-10-25T17:42:12Z | cmsg_01Q3o8RFpavsNskXDb46SG493UGL6Nx1BwPf1Kp7EYXXgc |
| 471 | Gate tests 691-end on stage 49bf68c7 | done | yes | 2026-10-25T17:32:40Z | cmsg_01Q3o8RFpavsNskXDb46SG49SHFWhUPEB9KMPnhbcb6U3L |
| 472 | Red-team stage 49bf68c7 before promotion | done | yes | 2026-10-25T17:28:45Z | cmsg_01Q3o8RFpavsNskXDb46SG499aXLtAcqkEBBkVF6upb9Dp |
| 473 | Gate bots shard 4 on stage 49bf68c7 | done | yes | 2026-10-25T17:26:51Z | cmsg_01Q3o8RFpavsNskXDb46SG4963hniVJEmdN5e5oUZK8fzq |
| 474 | Gate bots shard 1 on stage 49bf68c7 | done | yes | 2026-10-25T16:54:51Z | cmsg_01Q3o8RFpavsNskXDb46SG49TX583Jhw2K1RGexdnooAai |
| 475 | Gate tests 1-345 on stage 49bf68c7 | done | yes | 2026-10-25T16:45:58Z | cmsg_01Q3o8RFpavsNskXDb46SG498mixJkemkzb9PaAHxn2Agu |
| 476 | Gate bots shard 2 on stage 49bf68c7 | done | yes | 2026-10-25T16:15:48Z | cmsg_01Q3o8RFpavsNskXDb46SG49AwMfTBVj9A7gzrmuKed5nQ |
| 477 | Gate bots shard 3 on stage 49bf68c7 | done | yes | 2026-10-25T15:58:33Z | cmsg_01Q3o8RFpavsNskXDb46SG49S2SvRpSsCxNWVDXVPUPd1U |
| 478 | Fix Spillway dam canyon-rim wedge | done | yes | 2026-10-25T10:20:56Z | cmsg_01Q3o8RFpavsNskXDb46SG49MwQejEaoUpxPErC9jn9Uh8 |
| 479 | Red-team stage cf07ff61 before promotion | done | yes | 2026-10-25T08:33:53Z | cmsg_01Q3o8RFpavsNskXDb46SG49BWg1CWY6mpEHwP4qmT4SMX |
| 480 | Gate tests 691-end on stage cf07ff61 | done | yes | 2026-10-25T08:26:01Z | cmsg_01Q3o8RFpavsNskXDb46SG49Vz6eQCkcFYdgQGKmjHxkkV |
| 481 | Gate tests 346-690 on stage cf07ff61 | done | yes | 2026-10-25T07:00:34Z | cmsg_01Q3o8RFpavsNskXDb46SG494UCtawPCA5fsnTFXdd452m |
| 482 | Gate bots shard 5 on stage cf07ff61 | done | yes | 2026-10-25T06:58:15Z | cmsg_01Q3o8RFpavsNskXDb46SG49JL21KR8kbc5GZiG3sMRJ1G |
| 483 | Gate band reads on stage cf07ff61 | done | yes | 2026-10-25T06:44:07Z | cmsg_01Q3o8RFpavsNskXDb46SG492VYQheAKdqHfwx2gpu7BCE |
| 484 | Gate tests 1-345 on stage cf07ff61 | done | yes | 2026-10-25T06:22:14Z | cmsg_01Q3o8RFpavsNskXDb46SG49XorTZDDSrJwEAMqCnS9DHK |
| 485 | Gate bots shard 4 on stage cf07ff61 | done | yes | 2026-10-25T05:55:42Z | cmsg_01Q3o8RFpavsNskXDb46SG49UJJnhzqYJLLwf2iys8ktVQ |
| 486 | Gate bots shard 6 on stage cf07ff61 | done | yes | 2026-10-25T05:45:52Z | cmsg_01Q3o8RFpavsNskXDb46SG49X6cmVaxiAzZZm8FuvJH5EJ |
| 487 | Gate bots shard 2 on stage cf07ff61 | done | yes | 2026-10-25T05:44:44Z | cmsg_01Q3o8RFpavsNskXDb46SG49DE3TbeVSTRxP6ZHiMX7Y4A |
| 488 | Gate bots shard 1 on stage cf07ff61 | done | yes | 2026-10-25T05:42:00Z | cmsg_01Q3o8RFpavsNskXDb46SG4916BZNxJRBhWCBsozKRYod9 |
| 489 | Gate bots shard 3 on stage cf07ff61 | done | yes | 2026-10-25T05:35:23Z | cmsg_01Q3o8RFpavsNskXDb46SG49A8YdLbNAccsatLP8xfKDuU |
| 490 | Gate band reads on stage 31c8a24e | done | yes | 2026-10-25T04:56:53Z | cmsg_01Q3o8RFpavsNskXDb46SG495QsRw5T7JTQHaKbWvQpJQk |
| 491 | Fix Warden lock test after flume fix | done | yes | 2026-10-25T04:49:39Z | cmsg_01Q3o8RFpavsNskXDb46SG49MjWKN78Rv1S5VJTLBwYfST |
| 492 | Gate tests 691-end on stage 31c8a24e | done | yes | 2026-10-25T04:28:37Z | cmsg_01Q3o8RFpavsNskXDb46SG49DTiMCDgTqezXwbCML864Qb |
| 493 | Gate tests 346-690 on stage 31c8a24e | done | yes | 2026-10-25T04:28:06Z | cmsg_01Q3o8RFpavsNskXDb46SG49YPFE5twxFF5oU5wKLLh4E1 |
| 494 | Gate band reads on stage 8f2e20c9 | done | yes | 2026-10-25T03:31:41Z | cmsg_01Q3o8RFpavsNskXDb46SG49J58CfhUesLt8GMJYrL7YXa |
| 495 | Gate bots shard 5 on stage 31c8a24e | done | yes | 2026-10-25T03:12:03Z | cmsg_01Q3o8RFpavsNskXDb46SG49MX9DnmqG8jJ2g1Fy2Skhv9 |
| 496 | Gate tests 1-345 on stage 31c8a24e | done | yes | 2026-10-25T03:08:02Z | cmsg_01Q3o8RFpavsNskXDb46SG49VBbcLR5wURStgUw8pGHge6 |
| 497 | Gate bots shard 4 on stage 31c8a24e | done | yes | 2026-10-25T02:59:48Z | cmsg_01Q3o8RFpavsNskXDb46SG49BfDHgF78BkYDvJnL91rRG6 |
| 498 | Red-team stage 31c8a24e before promotion | done | yes | 2026-10-25T02:53:13Z | cmsg_01Q3o8RFpavsNskXDb46SG49KKCAX8W3viUoqKwivaBpCg |
| 499 | Gate tests 691-1034 on stage 8f2e20c9 | done | yes | 2026-10-25T02:47:08Z | cmsg_01Q3o8RFpavsNskXDb46SG49Tt5GVGTvSZMCY8YrWyAuvG |
| 500 | Gate bots shard 1 on stage 31c8a24e | done | yes | 2026-10-25T02:35:43Z | cmsg_01Q3o8RFpavsNskXDb46SG49KWhb6UTe5BUpk49KEn48Es |
| 501 | Gate bots shard 6 on stage 31c8a24e | done | yes | 2026-10-25T02:33:13Z | cmsg_01Q3o8RFpavsNskXDb46SG49YMHHR5vHE7BcGjjUzuvepP |
| 502 | Gate bots shard 2 on stage 31c8a24e | done | yes | 2026-10-25T02:31:20Z | cmsg_01Q3o8RFpavsNskXDb46SG49JnQXFuUFV14w24CZAzCgrp |
| 503 | Gate bots shard 3 on stage 31c8a24e | done | yes | 2026-10-25T02:28:38Z | cmsg_01Q3o8RFpavsNskXDb46SG49HJAThz8yYVoyZ92nDwaL2m |
| 504 | Gate tests 346-690 on stage 8f2e20c9 | done | yes | 2026-10-25T02:09:23Z | cmsg_01Q3o8RFpavsNskXDb46SG49XJdF5KERWPfpbTDrFxAtYb |
| 505 | Gate bots shard 5 on stage 8f2e20c9 | done | yes | 2026-10-25T01:11:00Z | cmsg_01Q3o8RFpavsNskXDb46SG496juKVTh6SqBiT6X6wM1Rri |
| 506 | Gate bots shard 2 on stage 8f2e20c9 | done | yes | 2026-10-25T01:05:11Z | cmsg_01Q3o8RFpavsNskXDb46SG498TtdspiueiLqTdcrKeRWLN |
| 507 | Gate bots shard 4 on stage 8f2e20c9 | done | yes | 2026-10-25T01:01:04Z | cmsg_01Q3o8RFpavsNskXDb46SG49GTEEY7KZVk6JYge7JAXj6N |
| 508 | Red-team stage 8f2e20c9 before promotion | done | yes | 2026-10-25T00:59:46Z | cmsg_01Q3o8RFpavsNskXDb46SG499wAq5tGpgZdEtJaAryf6mo |
| 509 | Listen to Brindle and Warden music on phone | done | yes | 2026-10-25T00:48:06Z | cmsg_01Q3o8RFpavsNskXDb46SG49Cg5iJixyN4Unoso6tjgmWT |
| 510 | Gate bots shard 3 on stage 8f2e20c9 | done | yes | 2026-10-25T00:37:02Z | cmsg_01Q3o8RFpavsNskXDb46SG495FHbrnVwxVLqESF7ZB5BUn |
| 511 | Gate bots shard 6 on stage 8f2e20c9 | done | yes | 2026-10-25T00:28:21Z | cmsg_01Q3o8RFpavsNskXDb46SG49Un4kUaZ5TSrNpsL6JGnLQs |
| 512 | Gate bots shard 1 on stage 8f2e20c9 | done | yes | 2026-10-25T00:22:26Z | cmsg_01Q3o8RFpavsNskXDb46SG49WrFfcyDaFESJKSnRA87pfK |

## Open PRs, live check with gh on 2026-11-14 (this table wins over the one above)

| PR | Head branch | Base | Title |
|---|---|---|---|
| [#1036](https://github.com/bananahana720/scrapkeep/pull/1036) | claude/project-thread-q5izsh | stage/alpha-w41 | Docs baseline: one home for live state, newest rulings win |
| [#1035](https://github.com/bananahana720/scrapkeep/pull/1035) | claude/project-thread-kjv6sg | stage/alpha-w41 | Approach and yard models: weighbridge fades under the eye, striped plate, crate pieces, ring flags, siren mast; yard test flake fixed |
| [#1034](https://github.com/bananahana720/scrapkeep/pull/1034) | claude/project-thread-c3a13w-enemies | stage/alpha-w41 | Tripo chaser that passes the render check; hooker barrel with no feet (stacks after PR 1031) |
| [#1033](https://github.com/bananahana720/scrapkeep/pull/1033) | claude/project-thread-m0mygp | stage/alpha-w41 | Dam yard: move the apron kicker past the shut yard so the play camera sees the floor |
| [#1031](https://github.com/bananahana720/scrapkeep/pull/1031) | claude/project-thread-c3a13w | stage/alpha-w41 | Arena props (scooter, parade crew) and a sluice shed that keeps its water wheel |
| [#1027](https://github.com/bananahana720/scrapkeep/pull/1027) | claude/project-thread-je1wl6 | stage/alpha-w41 | Handle enemies met in one tick in an order the game state sets |
| [#1018](https://github.com/bananahana720/scrapkeep/pull/1018) | claude/project-thread-rrf0av | stage/alpha-w41 | A played launch ends the run won at Brindle while worlds 2 and 3 are parked (ruling dr) |
| [#948](https://github.com/bananahana720/scrapkeep/pull/948) | claude/project-thread-nbxgus | stage/alpha-w41 | World 1 critique rows W1-63/77, W1-65, W1-67 (stacks after PR 845; W1-66 held) |
| [#845](https://github.com/bananahana720/scrapkeep/pull/845) | claude/project-thread-xfn8k2 | stage/alpha-w41 | Re-land the world 1 difficulty stack with its gate reds fixed |
| [#771](https://github.com/bananahana720/scrapkeep/pull/771) | claude/project-thread-ejf1g2 | stage/alpha-w38 | Twin lines prototype: swing on one line, sling between two (flag off by default) |
