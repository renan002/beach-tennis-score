# Monetize with a free core and a one-time Pro unlock, all commerce on the phone

The app is free, and every capability stays free: scoring in both sports,
Match History, the Game Log, and the Cartão de Resultado (with a small app
watermark). A single lifetime **Pro** in-app purchase (launch price R$19,90)
gates only comfort and insight: Estatísticas, the watermark-free Cartão de
Resultado, and Vários (the per-match sport picker — a free player switches
sports via the iPhone setting instead). StoreKit and every Pro touchpoint live
exclusively in the iOS target; the watch app has no purchase UI and no paywall.

The context this was decided in: the app has essentially no users yet and
acquisition is App Store search only, so nothing may throttle downloads or
risk the ratings the search ranking feeds on. The watermark is deliberately a
marketing channel, not a defect — beach tennis in Brazil is an Instagram-heavy
culture, and every shared free-tier card advertises the app. The rollout order
follows the same logic: the Cartão ships first, free and watermarked (1.4);
Estatísticas, the Pro unlock, watermark removal, and the Vários gate follow
(1.5), by which time early users have match histories that make Estatísticas
worth paying for.

This is hard to reverse in one direction only: a gated feature can always be
made free later, but a free feature can never be moved behind the paywall
without breaking faith with existing users. That asymmetry is why capability
is free — the line is meant to hold permanently.

## Considered Options

- **Paid upfront** — rejected. It strangles the search-only acquisition
  funnel; nobody impulse-buys an unknown watch app, and download velocity is
  what the ranking needs.
- **Subscription** — rejected. There is no backend and no recurring cost to
  justify renewals; utility-app subscriptions get punished in exactly the
  reviews the search ranking depends on, and the target market is
  subscription-averse for utilities. Revisit only if the app ever grows
  server-backed features.
- **Ads** — rejected. Unusable on the watch, where all the usage is; the
  iPhone companion is opened too rarely to earn anything.
- **Gating a sport (tennis = Pro)** — rejected. It puts a paywall on
  capability and on the pre-match flow, contradicting the free-capability
  line; the Vários gate keeps the same instinct but sells only convenience,
  since both sports remain reachable for free via the iPhone setting.
- **Purchase or upsell UI on the watch** — rejected. The watch is the primary
  scoring surface and stays pure; its only Pro-adjacent touchpoint is a
  one-line "see your stats on iPhone" hint after a match ends.
