# Work orders and logbook

From the title (or Achievements footer / Camp), `O` opens the three-tab Work Orders board (Orders, Licenses, Overrides) where the player pins crew and rotating shift orders, tracks maker license stamps, and arms unlocked Foreman override codes. `L` opens the five-tab Logbook (Entries, Crew arcs, Chemistry, Wire trail, Foreman) holding field entries, pilot story time cards, pilot pairings, Patch's unsigned wire trail, and the Foreman's habit audit.

## Sub-features

- `WO-1` `O` on the title opens `WorkOrdersPage` on the `Orders` tab with Crew clip / Shift clip cards, rotating shift orders, and crew orders.
- `WO-2` Tab buttons (or `Q`/`E`) switch to `Licenses` (maker license cards and stamp count) and `Overrides` (six Foreman override codes and four permanent head starts); `Esc` returns to the title.
- `WO-3` `L` on the title opens `LogbookPage` on the `Entries` tab showing logged field entries and the detail panel.
- `WO-4` Tab buttons (or `Q`/`E`) switch across all five tabs: `Entries`, `Crew arcs`, `Chemistry`, `Wire trail` (Patch's 6-node trail, labelled `Unsigned` until revealed), and `Foreman` (habit audit, dormant until three shifts); `Esc` returns to the title.
- `WO-5` Achievements (`A`) also exposes footer buttons for `Work orders` (`O`) and `Logbook` (`L`) that jump straight to either page.

## How to get to it (user POV)

- On the title: press `O` for Work orders or `L` for Logbook.
- From Achievements (`A`): click `Work orders` / `Logbook` in the footer, or press `O` / `L`.
- From Camp (`K`): open the Work orders or Logbook station / menu buttons.

## Driving it with drive.sh

Preconditions: baseline; game flag `--no-intro`.

- **Whole feature:** `$S/drive.sh .agents/skills/scrapkeep-verify-game/features/steps/work-orders-and-logbook.steps work-orders-and-logbook -- --no-intro`. Expect exit 0 and 41 passed steps.
- **WO-5:** `click "Achievements"`, `until clickable "Work orders" 10`, `shot achievements-footer`, `click "Work orders"`.
- **WO-1, WO-2:** `until text "crew orders stamped" 10`, `shot work-orders-orders`, `click "Licenses"`, `until text "stamps earned" 10`, `shot work-orders-licenses`, `click "Overrides"`, `until text "override codes armed" 10`, `shot work-orders-overrides`, `key ESCAPE`, then verify `key O` opens Work Orders directly from the title too.
- **WO-3, WO-4:** `key L`, `until text "field entries logged" 10`, `shot logbook-entries`, then `click "Crew arcs"`, `click "Chemistry"`, `click "Wire trail"`, `click "Foreman"` with a `shot` on each tab, then `key ESCAPE`.

## Gotchas

- **Known product layout bug (seen at `46576920`, 25 Nov 2026):** Opening `WorkOrdersPage` or `LogbookPage` stretches `Screens._content` to ~1685 px tall, pushing their `Back` footer buttons off the 900 px viewport (`y=1629`) and leaving `AchievementsPage`'s footer (`Work orders`, `Logbook`, `Back`) pushed off-screen if Achievements is opened afterward. Use `Esc` to close `WorkOrdersPage`/`LogbookPage` and drive Achievements before them until the layout bug is fixed.
- On a fresh profile, all Foreman override codes are locked and the Foreman habit audit reads `AUDIT DORMANT` until three shifts are recorded. Pass `--profile=sitting` to inspect unlocked override codes and all crew arcs.
- Patch's `Wire trail` tab labels the trail `Unsigned` until `wo_patch_2` is stamped or pilot `line_splicer` is unlocked.
- Wait on `until clickable "Settings" 10` after `key ESCAPE` before sending the next title hotkey so the closing transition settles.
