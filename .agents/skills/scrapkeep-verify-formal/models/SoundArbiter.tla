---- MODULE SoundArbiter ----
EXTENDS Naturals

CONSTANTS
    GuardWardenOverChamp,  \* TRUE: Warden takes sectioned stage pack over live champion
    GuardUnpinBoss,        \* TRUE: unpinning radio in boss arena restores boss track
    GuardUltStack,         \* TRUE: ultimate/radio exit restores live champion pack
    GuardDeathClearsUlt,   \* TRUE: player death clears armed ultimate flight state
    GuardMelodyLease,      \* TRUE: melody lease preempts June on warning/directed/pack change
    GuardEpochTrim         \* TRUE: epoch check invalidates stale DJ trims on transition

VARIABLES
    flow,             \* "stage" | "boss" | "dead"
    warden_engaged,   \* BOOLEAN
    warden_sealed,    \* BOOLEAN
    warden_section,   \* "build" | "open" | "drop" | "break"
    boss_phase,       \* 1..3
    radio_state,      \* "live" | "track_pinned"
    champion_hyped,   \* BOOLEAN
    ult_armed,        \* BOOLEAN
    warning_on,       \* BOOLEAN
    deck_pack,        \* "stage_sec" | "flat_champ" | "boss_p1" | "boss_finale" | "radio_track" | "ult_flight" | "dead_cadence"
    melody_owner,     \* "lead_stem" | "june_answer" | "warning" | "none"
    dj_epoch,         \* 0..2
    trim_active,      \* BOOLEAN
    trim_epoch        \* 0..2

vars == <<flow, warden_engaged, warden_sealed, warden_section, boss_phase,
          radio_state, champion_hyped, ult_armed, warning_on,
          deck_pack, melody_owner, dj_epoch, trim_active, trim_epoch>>

TypeOK ==
    /\ flow \in {"stage", "boss", "dead"}
    /\ warden_engaged \in BOOLEAN
    /\ warden_sealed \in BOOLEAN
    /\ warden_section \in {"build", "open", "drop", "break"}
    /\ boss_phase \in 1..3
    /\ radio_state \in {"live", "track_pinned"}
    /\ champion_hyped \in BOOLEAN
    /\ ult_armed \in BOOLEAN
    /\ warning_on \in BOOLEAN
    /\ deck_pack \in {"stage_sec", "flat_champ", "boss_p1", "boss_finale", "radio_track", "ult_flight", "dead_cadence"}
    /\ melody_owner \in {"lead_stem", "june_answer", "warning", "none"}
    /\ dj_epoch \in 0..2
    /\ trim_active \in BOOLEAN
    /\ trim_epoch \in 0..2

ResolveDeck(fl, we, ws, bp, rs, ch, ua, old_pack) ==
    IF fl = "dead" THEN "dead_cadence"
    ELSE IF fl = "boss" /\ bp = 3 THEN "boss_finale"
    ELSE IF fl = "boss" /\ rs = "track_pinned" THEN "radio_track"
    ELSE IF fl = "boss" THEN
        IF GuardUnpinBoss THEN "boss_p1" ELSE old_pack
    ELSE IF we /\ ws /\ rs = "track_pinned" THEN "radio_track"
    ELSE IF we /\ ws THEN
        IF GuardWardenOverChamp THEN "stage_sec"
        ELSE IF ch THEN "flat_champ" ELSE "stage_sec"
    ELSE IF ua THEN "ult_flight"
    ELSE IF rs = "track_pinned" THEN "radio_track"
    ELSE IF ch THEN
        IF GuardUltStack THEN "flat_champ" ELSE "stage_sec"
    ELSE "stage_sec"

JuneAllowed(fl, we, ws, wsec, dp, warn) ==
    /\ fl = "stage"
    /\ dp = "stage_sec"
    /\ ~warn
    /\ ~(we /\ ws /\ wsec \in {"open", "drop", "break"})

ReconcileMelody(fl, we, ws, wsec, dp, warn, cur_owner, cur_epoch, cur_trim, cur_tepoch) ==
    IF warn THEN
        [owner |-> "warning", trim |-> IF GuardEpochTrim THEN FALSE ELSE cur_trim, tepoch |-> cur_epoch]
    ELSE IF cur_owner = "june_answer" /\ ~JuneAllowed(fl, we, ws, wsec, dp, warn) THEN
        [owner |-> IF GuardMelodyLease THEN "lead_stem" ELSE cur_owner,
         trim  |-> IF GuardEpochTrim THEN FALSE ELSE cur_trim,
         tepoch |-> cur_epoch]
    ELSE
        [owner |-> cur_owner, trim |-> cur_trim, tepoch |-> cur_tepoch]

NextEpoch(e) == IF e < 2 THEN e + 1 ELSE 0

ApplyArbiter(fl, we, ws, wsec, bp, rs, ch, ua, warn) ==
    LET dp == ResolveDeck(fl, we, ws, bp, rs, ch, ua, deck_pack)
        ep == IF dp /= deck_pack THEN NextEpoch(dj_epoch) ELSE dj_epoch
        rec == ReconcileMelody(fl, we, ws, wsec, dp, warn, melody_owner, ep, trim_active, trim_epoch)
    IN  /\ deck_pack' = dp
        /\ dj_epoch' = ep
        /\ melody_owner' = rec.owner
        /\ trim_active' = rec.trim
        /\ trim_epoch' = rec.tepoch

Init ==
    /\ flow = "stage"
    /\ warden_engaged = FALSE
    /\ warden_sealed = FALSE
    /\ warden_section = "build"
    /\ boss_phase = 1
    /\ radio_state = "live"
    /\ champion_hyped = FALSE
    /\ ult_armed = FALSE
    /\ warning_on = FALSE
    /\ deck_pack = "stage_sec"
    /\ melody_owner = "lead_stem"
    /\ dj_epoch = 0
    /\ trim_active = FALSE
    /\ trim_epoch = 0

ChampionJoins ==
    /\ flow = "stage"
    /\ ~champion_hyped
    /\ champion_hyped' = TRUE
    /\ ApplyArbiter(flow, warden_engaged, warden_sealed, warden_section, boss_phase,
                    radio_state, TRUE, ult_armed, warning_on)
    /\ UNCHANGED <<flow, warden_engaged, warden_sealed, warden_section, boss_phase,
                   radio_state, ult_armed, warning_on>>

ChampionDies ==
    /\ champion_hyped
    /\ champion_hyped' = FALSE
    /\ ApplyArbiter(flow, warden_engaged, warden_sealed, warden_section, boss_phase,
                    radio_state, FALSE, ult_armed, warning_on)
    /\ UNCHANGED <<flow, warden_engaged, warden_sealed, warden_section, boss_phase,
                   radio_state, ult_armed, warning_on>>

WardenEngages ==
    /\ flow = "stage"
    /\ ~warden_engaged
    /\ warden_engaged' = TRUE
    /\ warden_sealed' = TRUE
    /\ warden_section' = "build"
    /\ ApplyArbiter(flow, TRUE, TRUE, "build", boss_phase,
                    radio_state, champion_hyped, ult_armed, warning_on)
    /\ UNCHANGED <<flow, boss_phase, radio_state, champion_hyped, ult_armed, warning_on>>

WardenSectionChanges ==
    /\ flow = "stage"
    /\ warden_engaged
    /\ warden_sealed
    /\ \E next_sec \in {"build", "open", "drop", "break"} :
        /\ next_sec /= warden_section
        /\ warden_section' = next_sec
        /\ ApplyArbiter(flow, warden_engaged, warden_sealed, next_sec, boss_phase,
                        radio_state, champion_hyped, ult_armed, warning_on)
    /\ UNCHANGED <<flow, warden_engaged, warden_sealed, boss_phase,
                   radio_state, champion_hyped, ult_armed, warning_on>>

EnterBossArena ==
    /\ flow = "stage"
    /\ flow' = "boss"
    /\ boss_phase' = 1
    /\ warden_engaged' = FALSE
    /\ warden_sealed' = FALSE
    /\ warden_section' = "build"
    /\ champion_hyped' = FALSE
    /\ ult_armed' = FALSE
    /\ ApplyArbiter("boss", FALSE, FALSE, "build", 1,
                    radio_state, FALSE, FALSE, warning_on)
    /\ UNCHANGED <<radio_state, warning_on>>

BossPhase3Finale ==
    /\ flow = "boss"
    /\ boss_phase < 3
    /\ boss_phase' = 3
    /\ radio_state' = "live"
    /\ ApplyArbiter("boss", FALSE, FALSE, "build", 3,
                    "live", FALSE, FALSE, warning_on)
    /\ UNCHANGED <<flow, warden_engaged, warden_sealed, warden_section,
                   champion_hyped, ult_armed, warning_on>>

RadioPin ==
    /\ flow \in {"stage", "boss"}
    /\ ~(flow = "boss" /\ boss_phase = 3)
    /\ radio_state = "live"
    /\ radio_state' = "track_pinned"
    /\ ApplyArbiter(flow, warden_engaged, warden_sealed, warden_section, boss_phase,
                    "track_pinned", champion_hyped, ult_armed, warning_on)
    /\ UNCHANGED <<flow, warden_engaged, warden_sealed, warden_section, boss_phase,
                   champion_hyped, ult_armed, warning_on>>

RadioUnpin ==
    /\ flow \in {"stage", "boss"}
    /\ radio_state = "track_pinned"
    /\ radio_state' = "live"
    /\ ApplyArbiter(flow, warden_engaged, warden_sealed, warden_section, boss_phase,
                    "live", champion_hyped, ult_armed, warning_on)
    /\ UNCHANGED <<flow, warden_engaged, warden_sealed, warden_section, boss_phase,
                   champion_hyped, ult_armed, warning_on>>

UltimateStarts ==
    /\ flow = "stage"
    /\ ~ult_armed
    /\ ult_armed' = TRUE
    /\ ApplyArbiter(flow, warden_engaged, warden_sealed, warden_section, boss_phase,
                    radio_state, champion_hyped, TRUE, warning_on)
    /\ UNCHANGED <<flow, warden_engaged, warden_sealed, warden_section, boss_phase,
                   radio_state, champion_hyped, warning_on>>

UltimateEnds ==
    /\ flow = "stage"
    /\ ult_armed
    /\ ult_armed' = FALSE
    /\ ApplyArbiter(flow, warden_engaged, warden_sealed, warden_section, boss_phase,
                    radio_state, champion_hyped, FALSE, warning_on)
    /\ UNCHANGED <<flow, warden_engaged, warden_sealed, warden_section, boss_phase,
                   radio_state, champion_hyped, warning_on>>

WarningToggle ==
    /\ flow \in {"stage", "boss"}
    /\ LET next_w == ~warning_on
       IN /\ warning_on' = next_w
          /\ ApplyArbiter(flow, warden_engaged, warden_sealed, warden_section, boss_phase,
                          radio_state, champion_hyped, ult_armed, next_w)
    /\ UNCHANGED <<flow, warden_engaged, warden_sealed, warden_section, boss_phase,
                   radio_state, champion_hyped, ult_armed>>

DjStartJuneAnswer ==
    /\ JuneAllowed(flow, warden_engaged, warden_sealed, warden_section, deck_pack, warning_on)
    /\ melody_owner /= "june_answer"
    /\ melody_owner' = "june_answer"
    /\ trim_active' = TRUE
    /\ trim_epoch' = dj_epoch
    /\ UNCHANGED <<flow, warden_engaged, warden_sealed, warden_section, boss_phase,
                   radio_state, champion_hyped, ult_armed, warning_on, deck_pack, dj_epoch>>

DjEndJuneAnswer ==
    /\ melody_owner = "june_answer"
    /\ melody_owner' = "lead_stem"
    /\ trim_active' = FALSE
    /\ trim_epoch' = dj_epoch
    /\ UNCHANGED <<flow, warden_engaged, warden_sealed, warden_section, boss_phase,
                   radio_state, champion_hyped, ult_armed, warning_on, deck_pack, dj_epoch>>

PlayerDies ==
    /\ flow \in {"stage", "boss"}
    /\ flow' = "dead"
    /\ radio_state' = "live"
    /\ ult_armed' = IF GuardDeathClearsUlt THEN FALSE ELSE ult_armed
    /\ warning_on' = FALSE
    /\ ApplyArbiter("dead", warden_engaged, warden_sealed, warden_section, boss_phase,
                    "live", champion_hyped, IF GuardDeathClearsUlt THEN FALSE ELSE ult_armed, FALSE)
    /\ UNCHANGED <<warden_engaged, warden_sealed, warden_section, boss_phase, champion_hyped>>

Done ==
    /\ flow = "dead"
    /\ UNCHANGED vars

Next ==
    \/ ChampionJoins
    \/ ChampionDies
    \/ WardenEngages
    \/ WardenSectionChanges
    \/ EnterBossArena
    \/ BossPhase3Finale
    \/ RadioPin
    \/ RadioUnpin
    \/ UltimateStarts
    \/ UltimateEnds
    \/ WarningToggle
    \/ DjStartJuneAnswer
    \/ DjEndJuneAnswer
    \/ PlayerDies
    \/ Done

\* --- Player-facing invariants ---

WardenOwnsFightMusic ==
    (flow = "stage" /\ warden_engaged /\ warden_sealed /\ radio_state /= "track_pinned")
        => deck_pack = "stage_sec"

BossMusicInArena ==
    (flow = "boss" /\ radio_state /= "track_pinned")
        => deck_pack \in {"boss_p1", "boss_finale"}

BossFinaleWinsOverAll ==
    (flow = "boss" /\ boss_phase = 3)
        => deck_pack = "boss_finale"

UltimateRestoresChampion ==
    (flow = "stage" /\ champion_hyped /\ ~warden_engaged /\ radio_state = "live" /\ ~ult_armed)
        => deck_pack = "flat_champ"

DeathClearsUltFlight ==
    (flow = "dead") => ~ult_armed

OneMelodyNoClash ==
    (melody_owner = "june_answer")
        => JuneAllowed(flow, warden_engaged, warden_sealed, warden_section, deck_pack, warning_on)

NoStaleTrim ==
    trim_active => (trim_epoch = dj_epoch /\ melody_owner = "june_answer")

\* --- Reachability probes (each must break on a live model) ---

ProbeWardenOverChamp == ~(flow = "stage" /\ warden_engaged /\ champion_hyped /\ deck_pack = "stage_sec")
ProbeBossFinale == ~(flow = "boss" /\ boss_phase = 3 /\ deck_pack = "boss_finale")
ProbeBossRadioPin == ~(flow = "boss" /\ radio_state = "track_pinned" /\ deck_pack = "radio_track")
ProbeUltFlight == ~(flow = "stage" /\ ult_armed /\ deck_pack = "ult_flight")
ProbeJuneAnswer == ~(melody_owner = "june_answer" /\ trim_active)
ProbeDeath == ~(flow = "dead" /\ deck_pack = "dead_cadence")

Spec == Init /\ [][Next]_vars
====
