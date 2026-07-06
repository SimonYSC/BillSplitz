# BillSplitz User Flow v2 — Screens, States, Validation

Suggested repo location: `docs/flows/2026-07-05-billsplitz-user-flow-v2.md`

Supersedes `docs/flows/2026-05-22-billsplitz-mvp-user-flow.md`.
Companion to `docs/design/2026-07-05-billsplitz-design-system.md` (the "Tab"
neo-brutalist system) — that doc owns *how things look*; this doc owns *what
each screen does*. Both come from the design exploration canvas
("User flow with mockups" project).

## What changed since v1

1. **Payer-only payment details.** Payment method + handle move from
   per-participant to the payer alone. Session Setup gains a Payer section;
   participants are names only. Share summary gains one line:
   `Pay {payer} via {method} {handle}` and drops per-person handles.
   ⚠ Model change: remove `paymentMethod`/`handle` from `Participant`; add
   them to the session's payer (or a `Payer` struct).
2. **Split Board interaction replaced.** Mode buttons (Shared/Assigned/Split)
   + name chips are gone. New model: compact item list + long-press →
   "assign mode" (wiggle) → drag item onto a person bubble / All. See §Step 4.
3. Everything else (parsing, math, draft persistence, share text mechanics)
   is unchanged from v1.

## Flow overview

```
Start ──New Split──▶ 1 Session Setup ─▶ 2 Receipt Capture ─▶ 3 Receipt Review
  ▲  └─Continue Draft (resumes at saved step)                        │
  │                                                                  ▼
  └────Done (clears draft)── 6 Share ◀─ 5 Settlement ◀─ 4 Split Board
```

Linear stepper, 6 steps, Back always available, draft autosaves on every
change. One active session; local only; no accounts, no payment APIs.

---

## Entry — Start

- **New Split**: resets draft, opens Session Setup.
- **Continue Draft**: resumes at last saved step. Disabled state when no
  draft exists (subtitle "No saved draft yet").
- Flow list (1–6) is informational only.

## Step 1 — Session Setup

Sections: **Session** (title field) · **Payer** · **Participants**.

- Payer: picker over the people list (default: "You"), payment method picker
  (Venmo / Zelle / Cash App / Other) + handle field. Helper copy: "Covers the
  bill. Their payment details go in the shared summary so everyone knows
  where to send money."
- Participants: name fields with delete (✕). Delete disabled at 2 people —
  error copy "Keep at least two participants."
- **Add Participant** appends "Person N".
- **Next blocks** with inline reason:
  - empty title → "Name this split before continuing."
  - <2 named participants → "Add at least two participants."

## Step 2 — Receipt Capture

- Text editor is the primary input: one item per line, `Name Price`
  (e.g. `Pad Thai 16.50`). `Tax`/`Tip` lines are picked up automatically.
- **Choose Photo** (PhotosPicker): MVP fallback — photo is noted for OCR
  review; info strip explains OCR isn't wired yet and guides back to text.
  Continues to Review either way.
- **Use Sample** fills the demo receipt.
- **Parse Receipt** extracts items + tax + tip. Blocks if no line contains a
  price.
- **Next** re-parses automatically when the text changed since last parse.

## Step 3 — Receipt Review

- **Totals card**: Items subtotal (live-computed), Tax + Tip editable decimal
  fields, Receipt Total = items + tax + tip.
- **Items list**: name field, price field, category picker (Appetizer / Main /
  Drink / Dessert / Adjustment), delete. **Add Item** appends an empty row.
- Empty state (nothing parsed): "Parse receipt text or add items manually."
  Manual entry is first-class; OCR/parsing never blocks the split.
- **Next blocks** if any item has an empty name. Advancing applies the meal
  preset if nothing is assigned yet (see below).

## Step 4 — Split Board  ← redesigned

Compact one-screen list: every item shows name, category, price, and an
**assignment badge** (dashed + = unassigned; yellow initial(s) = assigned/
split; black ALL = shared).

- **Meal Preset** button (also auto-applied on first entry): Appetizer +
  Dessert + Adjustment → shared with everyone; Main + Drink → left
  unassigned. Warning strip counts the remainder: "3 items still need
  assignment."
- **Assign mode**: long-press any item → screen dims, all rows wiggle,
  bubbles pop above the held item (one per participant + **All**), "✕ Clear"
  chip below it.
  - First run only: coach mark "Drag an item onto a name" + Got It.
  - Drag: item lifts into a chip; original row becomes a dashed slot.
  - Drop on one person → **assigned**. Drop on another person later →
    **split** equally among the connected people (caption: "You + Maya ·
    Split ½ each"). Drop on All → **shared** with everyone.
  - Already-connected people show a check on their bubble while dragging
    that item.
  - **Clear** removes all of that item's connections.
- **Next blocks** until every item has an assignment (badge on every row);
  warning strip states the count. The disabled Next has no shadow (per
  design system).

## Step 5 — Settlement

Read-only.

- Per-person cards: total (headline) + items / tax / tip breakdown. The
  payer's card is highlighted (accent fill).
- Grand-total bar must equal the Receipt Total exactly.
- Math contract (unchanged): Decimal only, never Float. Shared/split items
  divide by their group size; tax + tip allocate proportionally to each
  person's item subtotal, rounded to cents; leftover cent goes to the
  largest share. Sample data: 28.68 + 29.32 + 14.55 = 72.55 ✓.
- If reached with unassigned items (shouldn't happen via UI): show blocking
  strip "Every receipt item must be assigned before settlement." — never
  silently wrong numbers.

## Step 6 — Share

- Plain-text summary block (mono), format:

```
THAI NIGHT — BASIL HOUSE
PAID BY YOU · TOTAL $72.55

WHO OWES WHAT
YOU ............ $28.68
MAYA ........... $29.32
JORDAN ......... $14.55

PAY YOU VIA VENMO
@sam-rivera

BREAKDOWN
YOU    items 22.33 tax 1.88 tip 4.47
...

— BILLSPLITZ
```

- **Share Summary** → system share sheet. **Copy** → pasteboard, label flips
  to "Copied" briefly. Plain text is required; image card is optional polish.
- **Done** → clears the saved draft, returns to Start.

## Sample data (used across mockups/tests)

Thai Night — Basil House. Payer: You (Venmo @sam-rivera). People: You, Maya,
Jordan. Items: Spring Rolls 8.50 (Appetizer, shared), Pad Thai 16.50 (Main →
You), Green Curry 17.00 (Main → You + Maya split), Thai Iced Tea 5.50 (Drink
→ Jordan), Mango Sticky Rice 9.00 (Dessert, shared). Tax 4.75, Tip 11.30,
Total 72.55.
