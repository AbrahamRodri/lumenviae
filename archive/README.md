# Archive

Pages retired from the public site on 7 October 2026, when the site
narrowed to praying the Rosary: today's mysteries, the five categories,
their meditation sets and the prayer page. They are kept here, outside
`lib/` and `test/`, so they neither compile nor run, and nobody has to
keep them working.

| Page | Was at | Module |
|---|---|---|
| Prayer dashboard | `/dashboard` | `LumenViaeWeb.Live.Dashboard.Index` (folded into the home page) |
| The iPhone app | `/app` | `LumenViaeWeb.Live.Home.App.Index` |
| How to Pray the Rosary | `/rosary-methods` | `LumenViaeWeb.Live.Home.Methods.Index` |
| True Devotion to Mary | `/true-devotion` | `LumenViaeWeb.Live.Home.TrueDevotion.Index` |
| St. Carlo Acutis | `/saint-carlo` | `LumenViaeWeb.Live.Home.SaintCarlo.Index` |
| Feedback | `/feedback` | `LumenViaeWeb.Live.Home.Feedback.Index` |

Each old address now answers with a permanent redirect to `/`
(`LumenViaeWeb.RedirectController`), because the addresses are linked
from outside the site.

## Bringing a page back

1. `git mv` its directory from `archive/lib/lumen_viae_web/live/` back
   under `lib/lumen_viae_web/live/`, and its tests from `archive/test/`
   back under `test/`.
2. Take its path out of the redirect list in `router.ex` and add its
   `live` route to the `:public` live session again.
3. Link it from the header (`components/nav.ex`) or the footer
   (`components/footer.ex`), and add it back to `priv/static/sitemap.xml`.
4. Run the tests. The pages were last working at commit `11363de`; the
   shared components they use may have moved on since.
