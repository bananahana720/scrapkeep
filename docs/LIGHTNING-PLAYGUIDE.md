# Lightning caster playtest

Open `/orchard.html`. The original yard at `/` remains a separate game.

This increment tests one lightning hero in one arena across three waves. The [approved scope and integration contract](project/INCREMENT-01-lightning-playtest.md) owns its boundaries. The [first-proof guide](FIRST-BUILD-PLAYGUIDE.md) describes the earlier controls, which this increment replaces.

## Start and move

Click **Enter the orchard** to capture the mouse. Move the mouse to look horizontally or vertically; WASD moves relative to the camera. Hold the right mouse button for focused third-person aim.

Space jumps. Press it again after releasing for one additional air jump. Descending onto a smaller enemy damages it and rebounds, restoring an air jump. Shift bursts in your movement direction, including in the air. Ctrl brakes on the ground. Side collisions push; deliberate bursts and descending impacts deal damage.

## Lightning kit

| Control | Action |
| --- | --- |
| Hold left mouse | Repeat aimed lightning bolts, chaining from a hit to nearby enemies. |
| Hold Q, then release | Preview and cast a circular ground strike. |
| Hold E, then release | Preview and place an autonomous storm conductor. |
| R | Activate eight seconds of Overcharge when the ultimate meter is full. |

Tapping Q or E quick-casts. Invalid ground placement spends no cooldown. Escape cancels a prepared spell. Opening a menu cancels queued actions. The browser may also release mouse capture when Escape is pressed.

The preview starts at the weapon and shows the resolved impact point. Aim downward to place ground abilities while airborne. Terrain can obstruct a shot or invalidate a placement. Amber ground warnings mark low attacks; taller danger uses coral warnings with vertical bounds. Jumping helps only when the ball actually clears the damaging height.

Keep up to two conductors active. Placing another replaces the oldest. Nearby conductors connect; deployment uses cooldown and capacity, with no scrap cost. Successful multi-target lightning attacks earn ultimate charge. Overcharge increases chain reach and conductor activity.

## Waves and equipment

Defeat all enemies to finish a wave. New groups announce their entry, with at most fourteen active workers plus the boss. Two workers can prepare attacks at once alongside the boss. The final wave requires clearing both its workers and the Pruner arm.

Collect scrap, repairs, Shear Linkages and Braces automatically by moving nearby. Scrap grows the ball, Shear strengthens rams and unlocks the companion, and Brace improves burst recovery. The first Shear Linkage equips the priming companion automatically.

| Reward break | Choose one |
| --- | --- |
| After wave one | **Ground Loop**, adding lightning chains to body impacts, or two Brace parts. |
| After wave two | **Echo**, repeating compatible attacks once at half strength, or two Shear parts. |

Ground Loop and Echo work together. Echo also applies to compatible conductor and companion attacks, and never generates another echo. Acquired major items remain available for enabling or disabling between waves. Unchosen rewards are not acquired. Use the explicit **Continue** action when ready for the next wave.

## Dashboard and settings

I opens the dashboard; Escape pauses or closes it. Solo simulation pauses and the cursor is released. Character shows effective statistics; Equipment and Companion allow changes during reward breaks; Map shows the current arena; Settings controls sensitivity, audio, interface scale and impact shake. Use Tab and Shift+Tab to navigate menu controls. Restart is in the dashboard and results screen.

Resuming captures the mouse again. If capture fails, the game pauses with a **Capture mouse & resume** action. A recovery click does not fire. Keys held while opening a menu must be released before using them again.

The controller mapping is left stick movement, right stick look, A jump, B burst, RT primary, LT focus, LB strike, RB conductor, Y ultimate, View dashboard and Start pause. Hardware controller validation is separate from the browser and simulation checks. Touch controls are outside this playtest.

## Andrew's next playtest

Play through the first reward break, then try Ground Loop and Echo together. The questions are whether looking and shooting feel natural, jumping through enemies stays controllable, the waves feel dense enough, and health, cooldowns and threats can be read without searching or squinting. Those judgments require your playtest; automated checks establish behavior and measured performance only.
