# Rulesets are stamped by value onto matches, and the Ruleset library lives outside SwiftData

#61 made the rules configurable — best-of-N, points per game, serve rotation,
truco's target — and let players save and name their own Rulesets. Two decisions
follow from that, both hard to undo once matches exist in the wild.

**A match stamps its whole Ruleset by value at its start**, name included, and
persists it as a `Codable` blob rather than looking today's setting up when the
match is read back. This is the same guarantee Team Names already have: changing
Regras never rewrites a match already played. A live lookup would silently
corrupt Match History — a stored 3–1 ping pong match re-read under a best-of-5
Ruleset looks *unfinished*, and the Headline Score rule, which collapses to
points when the Ruleset makes the games level degenerate, cannot be computed at
all without the rules the match was actually played under. Stamping the whole
Ruleset as one blob (the trick `gameHistoryData` and `setHistoryData` already
use) rather than a column per knob means adding a rule knob later does not touch
the SwiftData schema.

**The Ruleset library is stored in `UserDefaults`/JSON, never as a SwiftData
`@Model`.** The SwiftData container is the Match History, and it is the fragile
thing in this codebase: ADR 0003, `StoreRecovery`, Quarantined Stores and the
lightweight-migration rule from #47 all exist because opening that store can
fail. A second `@Model` in the same container would put Ruleset schema changes
into the Match History's migration path, so a botched Ruleset migration could
quarantine a player's entire match history. Rulesets are small, few, and
non-relational; they have no business sharing that failure domain.

## Consequences

Only the *active* Ruleset per sport crosses to the watch, as one versioned blob
key in `WatchSettings` — all sports' active Rulesets, because with Vários the
watch chooses the sport after the context arrives and must already hold them.
The library itself stays on the phone: the watch scores, it does not configure.
