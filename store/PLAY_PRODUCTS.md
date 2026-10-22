# Google Play products for Ringburst

Every id below must exist in the Play Console (Monetize › Products › In-app products)
before the shop works in a Play build. Prices are set in the Console; the game shows
Google Play's localised price and falls back to the regional prices in
`game/autoload/store.gd` until Play answers. The full list (104 products) is in
`store/products.csv`; `python3 store/play_products.py create KEY.json` creates them all.

| Product id | Type | What it gives | Price (INR) / suggested US |
|---|---|---|---|
| `complete_pack` | One-time (non-consumable) | Everything: no banner ads, revive without videos, all themes and ring styles | ₹449 / $5.99 |
| `supporter_pack` | One-time | No banner ads; revive without watching a video | ₹249 / $2.99 |
| `theme_pack` | One-time | 11 colour themes for the app and arena (1-hour trial from a video) | ₹149 / $1.99 |
| `style_pack` | One-time | 6 ring styles (1-hour trial from a video) | ₹149 / $1.99 |
| `tip_10` … `tip_1000` (steps of 10) | Consumable | A tip: nothing unlocked (priced in rupees) | ₹10 × n |

There are no coins any more: if the old coin bags (`coins_500` … `coins_10000`) were
already created in the Play Console, set them to inactive there; the game no longer
sells them.

Consumables (tips) are consumed after granting, so they can be bought again. One-time packs
are acknowledged and restored on every launch and from **Restore purchases**.

## Ads (AdMob)

Set three repository secrets so CI builds use the real units (otherwise Google's test
units are used): `ADMOB_APP_ID`, `ADMOB_BANNER_ID` (anchored adaptive banner) and
`ADMOB_REWARDED_ID` (rewarded video). There are no interstitials. The banner shows at
the bottom of menus and result cards (never during a level, where the whole screen is
the control), except for Supporters; rewarded videos only play when the player asks
(a revive or a 1-hour pack trial). The banner
loads a fresh ad when the player changes screens, at most once every 30 seconds.
