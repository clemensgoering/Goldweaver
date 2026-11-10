# Goldweaver – Schnittstellen zwischen Modulen

Stand: 08.11.2026 (nach dem Architektur-Durchgang). Jede Session, die eine Schnittstelle ändert, aktualisiert diese Datei im selben Commit. „→" ist der Rückgabewert. Erweiterungspunkte sind mit ★ markiert (Details in `13-ARCHITEKTUR.md` §3).

## Core
| Objekt | Funktionen |
|---|---|
| `ns` (Init) | `Print(...)`, `Log(...)`, `RegisterModule(name, {Init, SelfTest})`, `EachModule(fn)`, `Slash.Register(cmd, fn, help)` ★, `L[key]`, `version` |
| `ns.Locale` | `Set(code) → active`, `Resolve(code)`, `Client()`, `active`, `tables[code]`, `LANGUAGES`; code = `"auto"`, `"deDE"` oder `"enUS"`, Einstellung `settings.language` (nil = automatisch), `/gw lang de/en/auto` |
| `ns.Events` | `On(event, fn, owner?)`, `Off(event, fn)`, `Summary()`, `skipped`; `ns.Health.Record(where, err)`, `.errors`, `.detached` |
| `ns.Secret` | `IsSecret(v)`, `Any(...)`, `Safe(v, fallback)` |
| `ns.API` | `Has(path)`, `Resolve(path)`, `Call(path, ...) → ok, ...`, `ItemInfo(id) → {name, quality, reqLevel, equipLoc, sellPrice, classID, subclassID, bindType, icon}`, `ItemInfoInstant(id)`, `ItemName/ItemIcon/ItemCount`, `NumSlots/FreeSlots/ContainerItem(bag, slot)/UseContainerItem`, `failures` |
| `ns.Features` | `Define(name, {label, requires})` ★, `Available(name) → ok, why`, `Missing(name)`, `SetEnabled(name, on)`, `Status()` |
| `ns.DB` | `Prepare(db)`, `Backup(reason, db?)`, `HasBackup()`, `RestoreBackup()`, `Stats()`, `MIGRATIONS` ★, `SCHEMA`; `ns.db`, `ns.cdb`, `ns.INTERFACE` |
| `ns.Util` | `Money(copper)`, `AfterCut(copper, cut?)`, `Round(x, digits)` |
| `ns.Chars` | `Names() → first, surname`, `FullName()`, `MailName(rec?)`, `ParseRealm(name) → region, ruleset`, `NormalizeMarket(key)`, `MarketKey()`, `Current()`, `Register()`, `Migrate()`, `UpdateProfessions()`, `SetRole(name, role)`, `ByRole(role, market?)`, `All(market?)`, `WithProfession(skillLine, market?)`, `Unassigned()`, `Changed()`, `ROLES`, `ROLE_LABELS` |
| `ns.Inventory` | `BagItems() → {{bag, slot, itemID, count, quality, isBound, isLocked, link}}`, `FreeBagSlots()`, `Count(itemID, {bank, alts}) → total, {bags, bank, alts}` |
| `ns.Price` | `RegisterSource(name, priority, fn)` ★, `Get(itemID) → {copper, source, age, confidence}`, `Copper(itemID)`, `Observe(itemID, unit, qty?, now?)`, `Observed(itemID, now?)`, `Prune(days, now?)`, `VendorSell(itemID)`, `VendorBuy(itemID)`, `Confidence(age, count)` |
| `ns.Graph` | `Add(conv)` ★, `Remove(id)`, `RemoveSource(source, profession?)`, `ForInput/ForOutput(itemID)`, `InputQty(conv, itemID)`, `OutputValue(conv, priceFn) → value, coverage`, `InputCost(conv, priceFn, exclude?) → cost, missing`, `Margin(conv, priceFn, cut?)`, `Count()` |

## Daten (`ns.Data`)
`Item(id, name)`, `ExpectedName(id)`, `AllItemIDs()`; `Disenchant.Outcomes/ExpectedValue/Conversion`, `Crates.For/Value/FavorRate`, `VendorReagents[id] = {buy}`, `Conversions`, `LoadConversions()`

## Berufe
| Objekt | Funktionen |
|---|---|
| `ns.Professions` | `Register(profile)` ★, `Get(key)`, `BySkillLine(id)`, `All()`, `RankFor(profile, skill) → rank, next`, `SeedCost(profile, from, to, priceFn)`, `SKILL_LINES`, `DEFAULT_RANKS` |
| `ns.Adapter` | `Read() → skillLine, name`, `Book(skillLine) → {name, list, byID, when}`, `Learned/Unlearned(skillLine, rec?)`, `IsOpen()`, `Craft(recipeID, count) → ok, err`, `ChanceFor(difficulty)`, `RebuildGraph()`, `current`, `DIFFICULTY_NAMES` |
| Rezept (normalisiert) | `{ id, name, icon, outputItemID, qtyMin, qtyMax, reagents = {{item, qty}}, difficulty, numSkillUps, sourceType, craftable, hyperlink, isEnchant }` |

## Module
| Objekt | Funktionen |
|---|---|
| `ns.Checks` | `Define(id, {group, title, hint})` ★, `Pass/Fail/Skip(id, detail)`, `Get(id)`, `Status()`, `Summary()`, `NextPending(limit)`, `Reset()` |
| `ns.Learn` | `DepositSample(...)`, `CrateTooltip(itemID, name, lines)`, `MailResult(variant, ok)`, `MailVariant()`, `Craft(difficulty, skill)`, `SkillChanged(skill)`, `SkillupChance(difficulty)`, `RecipeFields(info, schematic)`, `EnumName(value, pattern)`, `TrainerServices(npc)`, `RecipeSource(recipe) → text, kind, itemID?`, `TrainerFor(skillLine, reqSkill)`, `Status()` |
| `ns.Advisor` | `RegisterProvider(name, fn)` ★, `Evaluate(item, ctx) → options[]`, `Best(item, ctx)`, `LiveContext(overrides)`; Aktionen `vendor | auction | convert | crate | keep` |
| `ns.Mail` | `AddRule(name, fn, position?)` ★, `rules`, `TargetFor(item) → rec, reason`, `Plan() → {[name] = {rec, items, value, count}}`, `Pending() → count, value, target` |
| `ns.Destroy` | `CanDisenchant()`, `Queue()`, `Show()`, `Toggle()`, `Refresh()` |
| `ns.Planner` | `CraftCost(recipe)`, `Candidates(skillLine, rec?)`, `Shopping(recipe, crafts)`, `NextRank(skillLine, rec?)`, `Plan(skillLine, rec?)`, `KeepReason(itemID)`, `Profitable(skillLine, rec?, limit)` |
| `ns.CraftProfit` | `Top(limit)` |
| `ns.Compare` | `Rows()` |
| `ns.Auction` | `Suggest(itemID, qty, duration?) → {unitPrice, market, source, age, deposit, net}`, `SearchFor(itemID)` |
| `ns.Ledger` | `RecordInvoice(index)`, `Totals(days)`, `TrackGold()`, `GoldDelta(day?)`, `SessionDelta()`, `RecordPurchase(itemID, qty, totalCopper)`, `UnitCost(itemID) → copper, "bought"|"crafted"`, `BreakEven(itemID, qty, deposit)`; Daten `GoldweaverDB.costs` (Schema 6) |
| `ns.Dashboard` | `Recommendations(limit) → {{text, value, action, color}}` |
| `ns.Steps` | `Build(limit) → {{id, icon, item, category, title, detail, value, actionLabel, action}}`, `RegisterSource(name, priority, fn(add, ctx))` ★, `ICON` |
| `ns.Field` | `CurrentZone() → zoneID, rawMapID, name`, `Analyze(zoneID?, rec?) → report`, `Route()` (RestedXP, lesend), `BestZones(rec?)`, `RecordGather(kind, items, zoneID)`, `SetWaypoint(mapID, x, y, label)` |
| `ns.Demand` | `Get() → {[itemID] = {qty, by, via}}`, `For(itemID)`, `Invalidate()` |
| `ns.Coop` | `Partner(rec?)`, `Team() → gatherer, crafter`, `Needs() → {gatherer, crafter, rows, plans, points, fromGatherer, fromMail}` (row: `item, need, have, gatherer, mail, crafter, here, source, via`), `RecordSent(rec, items)`, `ScanInbox()`, `Invalidate()`, `Shopping() → {item, need, have, missing, source, forRec}` (Teamliste oder eigener Plan), `session`, `SessionLine()`; Daten `chars[name].inventory.mail` und `.incoming` (Schema 5) |
| `ns.Merchant` | `BuyList()`, `SellList()`, `Refresh()`; Reiter unter dem Händlerfenster: Reparieren, Verkaufen (1 Item pro Klick), Kaufen (Planlücke) |
| `ns.Bank` | `Wanted(itemID)`, `TakeList()`, `StoreList()`, `Refresh()`; Reiter unter dem Bankfenster: Holen, Einlagern (1 Stapel pro Klick) |
| `ns.Trainer` | `Rows() → {index, name, cost, kind, profit?, payback?}`, `Refresh()`; Karte neben dem Lehrerfenster mit Lernen-Knopf je Zeile |
| `ns.CraftProfit` | `Top(limit)`, `Of(recipe) → Gewinn pro Herstellung nach AH-Anteil`; Gewinnmarken in Blizzards Rezeptliste |
| `ns.Field` (Fundorte) | `PlayerSpot() → {m, x, y}`, `Spots(zoneID, items?) → {m, x, y, item}`, `NearestNeededNode() → label` (Wegpunkt); Daten `learned.zoneGathers[zone][item].spots` (Schema 7, höchstens 40 je Item) |
| `ns.UI` (Ergänzung) | `FrameTabs(frame, n)` (Aktionsreiter unter Blizzard-Fenstern, `tab:Set(label, tip, onClick, enabled)`/`Clear()`), `ProgressRows`, `SetHeaderInfo`, `ApplyScale()` |
| `ns.Professions` (Ergänzung) | `ZoneFor(profile, skill) → {from, to, zone, note}`; Profile für alle zwölf Berufe |
| `ns.Autopilot` | `GuessRole(rec, market)`, `ReadQueue(rec?)`, `StartReading()`, `QuickHealth()`, `status` |
| `ns.Panel` | `Refresh()`, `Toggle()`, `ShouldShow()` |
| `ns.Settings` | `Open()` |
| `ns.HUD` | `Refresh()`, `ShouldShow()` |
| `ns.Onboarding` | `Check()` |
| `ns.Contacts` | `VendorFor(itemID)`, `Trainers()` |
| `ns.Debug` | `Build() → text`, `Show(text?)`, `Run()` |
| `ns.Tooltip` | `Lines(itemID, qty?, isBound?) → {{text, color}}` |

## UI
| Objekt | Funktionen |
|---|---|
| `ns.UI` | `RegisterTab(key, title, builder)` ★, `Open(key?)`, `Toggle(key?)`, `IsOpen()`, `Refresh()`, `SelectProfession(skillLine)`; Widgets `Text`, `Header`, `Button`, `Check`, `Group`, `Lines`, `Pairs`, `Table`, `IconRows`, `ItemName` |
| `ns.Minimap` | `SetBadge(n)`, `SetShown(bool)` |

## SavedVariables (Besitzer in Klammern)
`GoldweaverDB`: `schema`, `settings`, `chars` (Chars/Inventory/Adapter), `prices` (Price), `recipes` (Adapter), `observations` (Destroy), `learned` (Learn), `checks` (Checks), `contacts`/`vendors` (Contacts), `probe` (Probe), `debug` (Init/Events/Debug). `GoldweaverCharDB`: `ledger` (Ledger). `GoldweaverBackupDB`: eine Generation Backup (DB).

## Slash-Befehle
`/gw` Fenster · `help` · `show <tab>` · `role` · `chars` · `market` · `favor` · `undercut` · `hud` · `minimap` · `tooltip` · `de` · `mail` · `contacts` · `checks [reset]` · `feature` · `probe …` · `debug run|show|on|off` · `backup` · `restore confirm`
