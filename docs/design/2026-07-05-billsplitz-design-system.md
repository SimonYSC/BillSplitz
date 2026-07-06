# BillSplitz Design System — "Tab" (Neo-Brutalist)

Suggested repo location: `docs/design/2026-07-05-billsplitz-design-system.md`

Source of truth for the visual redesign chosen in the design exploration
(option 4b, rolled out across the full flow in 5a of the flow-map canvas).
Interaction model is the "wiggle + drag" Split Board (option 3c).
This doc is written for implementation in SwiftUI; every token includes a
suggested Swift name.

**Design intent in one line:** splitting a bill with friends is banter, not
banking — the UI is loud, chunky, and unmissable, like a paper tab slapped on
the table.

---

## 1. Design principles

1. **Everything looks pressable.** Interactive elements get a hard border and
   an offset shadow. Pressing visually "pushes" the element into its shadow
   (translate by the shadow offset, shadow collapses to 0).
2. **One accent, used with meaning.** Yellow is never decoration: it marks
   *the current step*, *the primary action*, and *live/assigned state*. If
   everything is yellow, nothing is.
3. **Ink on paper.** Near-black ink (`#111111`) on warm paper (`#F0EDE4`).
   No gradients, no blur, no translucency, no rounded corners (radius 0
   everywhere; circles are the single exception — people bubbles).
4. **Validation is loud but honest.** Blockers appear inline with the reason
   ("3 items still need assignment"), never as silent disabled buttons alone.
5. **The math is sacred.** Visual redesign never touches the money rules:
   Decimal-only arithmetic, proportional tax/tip allocation, leftover cent to
   the largest share, totals reconcile exactly.

---

## 2. Color tokens

| Token | Hex | Swift name | Usage |
|---|---|---|---|
| Paper | `#F0EDE4` | `Color.bsPaper` | Screen background |
| Paper-sunken | `#F5F2E9` | `Color.bsPaperSunken` | Inset wells: text editor, grouped sub-panels |
| Ink | `#111111` | `Color.bsInk` | Text, borders, shadows, filled progress blocks |
| Ink-muted | `#555555` | `Color.bsInkMuted` | Secondary text (breakdown rows, helper copy) |
| Disabled | `#999999` / `#777777` | `Color.bsDisabled` | Disabled borders & text |
| Disabled-shadow | `#C9C5B8` | `Color.bsDisabledShadow` | Offset shadow of disabled cards |
| Card | `#FFFFFF` | `Color.bsCard` | Card / row surfaces |
| Accent (yellow) | `#FFD500` | `Color.bsAccent` | Primary actions, current step, assigned state, payer highlight |
| Danger (red) | `#E03A2A` | `Color.bsDanger` | Delete affordances, destructive confirm |
| Warning | ink on yellow | — | Warnings reuse accent: yellow panel, ink border, ink text |

Dark mode: out of scope for MVP. The palette is light-only by design.

## 3. Typography

| Role | Font | Size/weight | Swift name |
|---|---|---|---|
| Display / titles | **Archivo Black** (single weight), ALL CAPS | 21pt screen titles, 38pt app name, 14pt card headers | `Font.bsDisplay(_:)` |
| Body / UI | **Space Grotesk** | 14pt semibold body, 12–13pt buttons (700, ALL CAPS), 10–11pt tags (700, ALL CAPS) | `Font.bsBody(_:weight:)` |
| Money & receipt text | **IBM Plex Mono** | 11.5–13pt, 500–600 | `Font.bsMono(_:)` |

Rules:
- Headers and buttons are ALWAYS uppercase.
- Money amounts in running UI use Space Grotesk bold; receipt-like blocks
  (capture editor, share summary) use IBM Plex Mono with dotted leaders.
- Minimum text size 10pt; body copy never below 12pt.

## 4. Borders, shadows, spacing

| Token | Value | Usage |
|---|---|---|
| `borderCard` | 3px solid Ink | Cards, hero tiles, big buttons |
| `borderControl` | 2.5px solid Ink | Inputs, rows, small buttons |
| `borderTag` | 2px solid Ink | Tags, chips, progress blocks |
| `borderDashed` | 2.5px dashed Ink | "Add" affordances, drop slots, empty wells |
| `shadowCard` | 6px 6px 0 Ink | Cards |
| `shadowButton` | 4px 4px 0 Ink | Large buttons |
| `shadowSmall` | 3px 3px 0 Ink | Small buttons, back chip, hero accent |
| Press state | translate(+offset), shadow → 0 | All shadowed elements |
| Corner radius | 0 | Everything except people bubbles (perfect circles) |
| Spacing scale | 4 / 8 / 12 / 16 / 20 | Screen gutter 20; card padding 14; row gap 9–12 |
| Hit targets | ≥ 44×44pt | Trash ✕, back chip, bubbles all qualify |

## 5. Components

### 5.1 Screen header
Back chip (38×38, card border+shadow, "←") · Archivo Black title, centered ·
spacer. Below: **progress blocks**.

### 5.2 Progress blocks (stepper)
Six equal blocks, 12pt tall, 6pt gap + "n/6" label.
- Completed: filled Ink.
- Current: Accent fill, Ink border.
- Future: Card fill, Ink border.

### 5.3 Cards
White, `borderCard`, `shadowCard`, 14pt padding. Header: Archivo Black 14pt
caps. Optional header-right action chip (small button).

### 5.4 Buttons
| Variant | Style |
|---|---|
| Primary | Accent bg, `borderCard`, `shadowButton`, caps, "Next →" |
| Secondary | Card bg, same border/shadow, "← Back" |
| Small | 2.5px border, `shadowSmall`, 11–12pt caps |
| Dashed/add | Dashed border, no shadow, "+ Add …" |
| Disabled | `#D6D2C6` bg, `#777` border+text, **no shadow** (nothing to press) |

### 5.5 Inputs
White field, `borderControl`, 9–10pt padding, semibold value. Pickers are
input-shaped with a trailing "▲▼". Field labels can be ink-on-ink tags
(black block, white caps text) beside the field (see Tax / Tip).

### 5.6 Assignment badges (item rows)
- **Unassigned:** dashed 2px square, gray "+".
- **Assigned:** Accent square, Ink border, person initial (one per person on a split).
- **Shared:** Ink square, Accent "ALL" text.

### 5.7 People bubbles (assign mode)
52pt circles, Card bg, `borderCard`, `shadowSmall`; label below in caps with
dark text-shadow (they sit over dimmed content). Hot/targeted: Accent bg,
scale 1.15, `shadowButton`. "All" bubble: Ink bg, Accent text. Non-targets
fade to 55%.

### 5.8 Status/help strip
Card-bordered white strip with a 22pt ink block icon (i / = / !) and 12.5pt
semibold copy. Warnings: Accent bg instead of white.

### 5.9 Person settlement card
Bordered block: name (Archivo Black caps) + total (Archivo Black 18pt) on the
first line, items/tax/tip caps breakdown below. The payer's card is Accent-
filled. Grand total bar: Ink bg, white caps label, Accent amount.

## 6. Interaction — Split Board (from 3c)

1. **Long-press any item** → assign mode: screen dims (`rgba(17,17,17,0.38)`),
   all rows wiggle (±1.2° rotation loop), people bubbles pop above the held
   item, "✕ CLEAR" chip below it.
2. **First run only:** coach mark card ("Drag an item onto a name") with a
   Got It button; never shown again after dismiss.
3. **Drag the item** — it lifts into a compact chip (name + price, `shadowCard`,
   −3° tilt); the original row stays as a dashed slot at 60% opacity.
4. **Drop on a person** → assigned. Drop on a second person later → split
   (caption chip: "You + Maya · Split ½ each"). Drop on **All** → shared.
5. **Clear** removes every connection for that item.
6. **Next** stays disabled until every item has a badge; the blocker count is
   shown in a warning strip, never silently.

Motion: wiggle 0.25s ease-in-out alternating; lift 0.15s spring; bubble
pop-in staggered 30ms; press-into-shadow 0.1s. Respect Reduce Motion: replace
wiggle with a pulsing border on the held item.

## 7. Voice & copy

Blunt, warm, a little cheeky — never corporate. Sentence-case helper copy,
ALL-CAPS labels. Examples used in the mockups: "THE DAMAGE" (share summary),
"WHO OWES WHAT", "Split the receipt. Everyone pays their share — down to the
cent." Validation copy stays specific: "Name this split before continuing.",
"Add at least two participants.", "3 items still need assignment."

## 8. SwiftUI implementation notes

- Ship tokens as `Color`/`Font` extensions (`Color.bsInk` etc.) plus a
  `BSShadow` view modifier that draws the offset-rect shadow (a `Rectangle`
  offset behind content — **not** `.shadow()`, which blurs).
- One `BSButtonStyle` handles the press-into-shadow behavior via
  `configuration.isPressed`.
- Fonts: bundle Archivo Black, Space Grotesk, IBM Plex Mono (Google Fonts,
  OFL). Register in Info.plist; fall back to `.system(.black)` / monospaced
  system font if unavailable.
- Progress blocks, badges, and bubbles are small enough to be plain `HStack`/
  `ZStack` views — no images needed anywhere in this system.
- Screens map 1:1 to the existing `AppFlowScreens.swift` structure; this is a
  reskin plus the new Split Board interaction, not an architecture change.
- Model change already reflected in mockups: payment method + handle move
  from per-participant to **payer only** (Payer section in Session Setup;
  share text gains a "Pay {payer} via {method} {handle}" line).
