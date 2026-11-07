# Beach tennis scoring rules

How `ScoreEngine` scores a beach tennis match. The rules are a Ruleset
(`BeachTennisRuleset`, `Shared/BeachTennisRules.swift`), stamped by value onto
each match at its start (ADR 0006). Vocabulary is in `CONTEXT.md`: Match Format,
Tiebreak, Deuce Rule.

Beach has no real sets: a match is one sequence of games, and the UI shows each
game as a "Set" (see the Set entry in `CONTEXT.md`). "Set" below means that unit.

## Padrão

The one Preset, and how every beach match was scored before rules were editable.
A beach Ruleset stamped before the payload existed scores as Padrão.

- First to 6 Sets, win by two Sets: 6–4 wins, 6–5 continues, 7–5 wins.
- At 6–6: a Tiebreak to 7 points, win by two. The winner takes the match 7–6.
- Points per game: 0 → 15 → 30 → 40 → game. At 40–40, golden point: the next
  point wins the game.

## Knobs

| Knob (pt-BR) | Values | Padrão |
|---|---|---|
| Formato | Primeiro a N / Sempre N | Primeiro a N |
| Sets (N) | 1–15 | 6 |
| Vencer por 2 sets | on / off (Primeiro a N only) | on |
| Tie-break | on / off | on |
| Pontos do tie-break | 5–21 | 7 |
| Tie-break: vencer por 2 | on / off | on |
| Em 40–40 | Ponto de ouro / Vantagem | Ponto de ouro |

**Primeiro a N.** The first side to N Sets wins. With *vencer por 2 sets* the
winner also needs a two-Set lead; then, with the Tiebreak on, N–N goes to a
Tiebreak, and with it off play continues until someone leads by two, uncapped.
Without *vencer por 2 sets*, N–(N−1) wins and a Tiebreak can never happen.

**Sempre N.** Exactly N Sets are played even after the result is decided — 2–0
in a Sempre 3 still plays the third. The side with more Sets wins. A match never
ends drawn: an even N tied at the end goes to a Tiebreak, so Sempre N with an
even N requires the Tiebreak on (the editor forces it).

**Tiebreak.** Won at *Pontos do tie-break*, with a two-point lead when *vencer
por 2* is on. It counts as one more Set in the Game Log and always ends the
match. "Super tie-break" is just a Tiebreak to 10.

**Em 40–40.** *Ponto de ouro*: the next point wins the game, recorded as `GP`.
*Vantagem*: the point winner takes the advantage; winning the next point wins
the game (recorded as `Ad`), losing it returns to 40–40.

## Serve (not a knob)

- The serve alternates every Set.
- In the Tiebreak the first server serves one point, then the serve alternates
  every two: `block = (pointsPlayed-1)/2; block%2==0 → other team serves`.
