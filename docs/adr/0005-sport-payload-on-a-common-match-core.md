# Sport-specific scoring state lives in a payload on a common `MatchState` core

Adding truco and ping pong (#61) meant one `MatchState` had to hold four sports
whose scoring state has almost nothing in common: truco has no serve, no
0/15/30/40 and no games-inside-sets, while ping pong counts integer points to a
configurable target. Rather than widen the existing flat struct further, we
split it: `MatchState` keeps the identity every match has — sport, Ruleset, team
names, dates, serving side, winner, Game Log — and a per-sport payload carries
the scoring state only that sport understands.

## Considered options

**Widen the flat struct.** This is what the codebase already did — beach tennis
leaves `setsWonA/B` and `advantageTeam` untouched, tennis leaves
`isGoldenPoint` untouched — and it was tempting because ping pong's game is
structurally identical to the existing tiebreak fields (integer points, win by
two, serve alternating every two from a named first server). It was rejected
because at four sports nothing in the type system would stop a truco match from
carrying an `advantageTeam`, and every invariant would live only in
`ScoreEngine`'s head. The fields would also have kept names (`tiebreak*`) that
lie about what ping pong uses them for, which `CONTEXT.md` exists to prevent.

**Separate state types per sport behind a protocol.** Cleanest on paper, but it
would rewrite the crash-restore encoding, the WatchConnectivity payload, and
every view's field access at once.

## Consequences

The flat wire and storage formats do not follow the payload. `StoredMatch` keeps
its existing columns and `MatchResultPayload` keeps its flat dictionary: the
Headline Score continues to reuse `setScoreA/B` for every sport, and the payload
carries only what those columns cannot express. This is deliberate — it means no
existing row changes meaning and no migration is needed for matches already in a
player's Match History.

`setScoreA/B` therefore holds a truco *point total* and a ping pong *games-won*
count despite the column name. See the Headline Score entry in `CONTEXT.md`,
without which the next reader will be badly misled.
