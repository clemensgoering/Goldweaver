# Goldweaver – Schnittstellen zwischen Modulen

Stand: 08.11.2026. Jede Session, die eine Schnittstelle ändert, aktualisiert diese Datei im selben Commit. Signaturen sind Lua; „→" ist der Rückgabewert.

## Core

### `ns` (Core/Init.lua)
- `ns.Print(...)`, `ns.Log(...)` (nur mit `/gw debug on`)
- `ns:RegisterModule(name, tbl)` – `tbl.Init()` wird nach `ADDON_LOADED` aufgerufen
- `ns.Slash.Register(cmd, fn(rest), help)` – `/gw <cmd> <rest>`
- `ns.L[key]` – Lokalisierung, fällt auf den Key zurück

### `ns.Events` (Core/Events.lua)
- `ns.Events:On(event, fn(event, ...))`, `ns.Events:Off(event, fn)`
- Handler werden übersprungen, wenn ein Argument ein Secret ist (`ns.Events.skipped` zählt)

### `ns.Secret` (Core/Secret.lua)
- `IsSecret(v)`, `Any(...)`, `Safe(v, fallback)`

### `ns.db`, `ns.cdb` (Core/DB.lua)
- `ns.db.settings` – `debug, favorValueCopper, ahCut, mailCostCopper, marketKey?, favorPerCrate?, priceHistoryDays?`
- `ns.db.chars[fullName]` – `{ name, role, market, faction, class, level, lastSeen, professions[skillLine] = { name, rank, maxRank } }`
- `ns.db.prices[marketKey][itemID]` – `{ min, avg, count, seen, days[dayKey] = { min, sum, units, n } }`
- `ns.db.observations` – Kalibrierlogs (Entzaubern, Skill-ups), Struktur legt WP1.6 fest
- `ns.db.probe[section]` – Ergebnisse von `/gw probe`

### `ns.Util` (Core/Util.lua)
- `Money(copper) → "12g 34s 56c"`, `AfterCut(copper, cut?)`, `Round(x, digits)`

### `ns.Chars` (Core/Chars.lua)
- `FullName()`, `MarketKey()`, `Current()`, `Register()`, `UpdateProfessions()`
- `SetRole(name, "main"|"processor"|"bank"|"none")`, `ByRole(role, market?)`, `WithProfession(skillLine, market?)`
- Slash: `/gw role`, `/gw chars`, `/gw market`

### `ns.Price` (Core/Price.lua)
- `RegisterSource(name, priority, fn(itemID) → copper, ageSeconds, count)` – kleinere Priorität zuerst. Belegt: auctionator 10, tsm 20, observed 30, vendorSell 90
- `Get(itemID) → { copper, source, age, confidence }` oder nil; `Copper(itemID) → copper|nil`
- `Observe(itemID, unitCopper, quantity?, now?)` – vom AH-Modul für jede gesehene Seite aufzurufen
- `Observed(itemID, now?) → copper, age, count`, `Prune(maxDays, now?)`
- `VendorSell(itemID)`, `VendorBuy(itemID)` (Deckel aus Data/VendorReagents)

### `ns.Graph` (Core/Graph.lua)
- Conversion: `{ id, kind, profession, skill, source = "live"|"profile"|"data", inputs = {{item, qty}}, outputs = {{item, qty, prob}}, name, recipeID? }`
- `Add(conv)`, `Remove(id)`, `RemoveSource(source, profession?)`, `ForInput(itemID)`, `ForOutput(itemID)`, `InputQty(conv, itemID)`
- `OutputValue(conv, priceFn) → value, coverage`, `InputCost(conv, priceFn, excludeItem?) → cost, missing`, `Margin(conv, priceFn, cut?) → net, coverage, missing`
- Konvention: Live-Rezepte benutzen `id = "craft:<outputItemID>"`, damit sie Profil-Startwerte gleicher ID ersetzen. Beim Schließen des Fensters bleiben Live-Kanten stehen; `RemoveSource("live", profession)` nur vor einem Neu-Einlesen.

## Daten (`ns.Data`)
- `Data.Item(id, name)`, `Data.ExpectedName(id)`, `Data.AllItemIDs()` – Namensregister für `/gw probe items`
- `Data.Disenchant.Outcomes(reqLevel, quality, isWeapon) → {{item, qty, prob}}`, `ExpectedValue(reqLevel, quality, isWeapon, priceFn) → copper, coverage`, `Conversion(itemID, reqLevel, quality, isWeapon)`
- `Data.Crates.For(itemID) → { category, tier, bundleQty, favor }`, `Value(itemID, qty, favorValueCopper, allowPartial) → copper, entry`, `FavorRate(tier)`
- `Data.VendorReagents[itemID] = { buy }`
- `Data.Conversions` (statisch), `Data.LoadConversions()`

## Berufe (`ns.Professions`, Professions/Registry.lua)
- `Register(profile)`, `Get(key)`, `BySkillLine(id)`, `All()`, `RankFor(profile, skill) → rank, nextRank`, `SeedCost(profile, from, to, priceFn) → copper, coverage`
- `SKILL_LINES`, `DEFAULT_RANKS`
- Profil-Felder siehe Dateikopf von Registry.lua. **Noch offen (WP2.1):** `ns.Recipes[professionKey]` als normierte Live-Rezeptliste aus `Professions/Adapter.lua`:
  `{ recipeID, name, difficulty = "optimal"|"medium"|"easy"|"trivial", reagents = {{item, qty}}, output = { item, qtyMin, qtyMax }, tools, station, learned }`
  und Events `ns.Events` → `GOLDWEAVER_RECIPES_UPDATED` (per `ns.Events.frame`-Callback oder eigene Callback-Liste, legt WP2.1 fest).

## Advisor (`ns.Advisor`, Modules/Advisor.lua)
- `Evaluate(item, ctx) → options[]` sortiert nach `value` absteigend; `Best(item, ctx) → best, options`
- `item = { id, quantity, reqLevel, quality, isWeapon, vendorSell, soulbound }`
- `ctx = { price, graph, settings, needsMail, canDisenchant, keepFor, crates, disenchant }`; `LiveContext(overrides)` baut ihn aus dem Spiel
- Aktionen: `vendor | auction | convert | crate | keep`

## Noch zu definieren (durch das jeweilige WP, hier eintragen)
- `ns.Inventory` (WP1.4): `Count(itemID, scope)`, `Snapshot(char)`, Events bei Taschenänderung
- `ns.UI` (WP1.7): `Window`, `List`, `Button`, `Tooltip.AddLines(tooltip, lines)`
- `ns.Mail` (WP1.5): `SendList(targetChar) → items[]`, `SendNext()`
- `ns.Planner` (WP2.2): `KeepReason(itemID) → string|nil`, `Plan(professionKey, targetSkill) → steps[]`
- `ns.Auction` (WP3.x): `Observe`-Hook auf Suchergebnisse, `Suggest(itemID) → { unitPrice, stack, deposit }`
