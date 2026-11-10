Gear Mover v1.3.5 — Synastria / World of Warcraft 3.3.5a

INSTALL
Extract the ZIP so that Interface/AddOns/Gear Mover/ contains
Gear Mover.toc, GearMover.lua, UI/, and Textures/.
Fully EXIT and restart WoW after installing: this version includes new
texture files which the client may not discover during /reload alone.
Your existing GearMoverDB settings are preserved.

INTERFACE — THREE LAYOUTS
Open the floating window using /ggm window (or open a supported bank).
Click the small > control in the upper right to cycle:
  1. Full: Centered Gear Mover title; individual Deposit/Withdraw buttons
     for Cloth, Leather, Mail, Plate, Weapons, plus Deposit All,
     Withdraw All, and Stop (enabled during a transfer).
  2. Compact: Two direction buttons (Deposit and Withdraw) above five
     abbreviated category buttons and one All/Stop button. The active
     direction controls the action performed by those buttons.
  3. Icons: Your supplied artwork for the selected direction (Bank for
     Deposit, Inventory for Withdraw), five equipment types, and a
     galaxy/black-hole All button. Hover an icon to see its action.
     The All icon works as Stop during a transfer.
Green indicates deposit; amber indicates withdraw. Switching layouts
or direction never starts a transfer or changes a bank tab.
The selected layout, direction, window position, and size are saved
account-wide and restored across reloads and logins.
Drag the small bottom-right corner grip to scale the complete window
between 65% and 165% of its normal size. This preserves button/icon
proportions in all three layouts and uses no idle OnUpdate polling.

SETTINGS — /ggm
Each equipment category has one compact multi-tab selector. Click it
and toggle any combination of guild tabs 1–6; click the selector again
or outside the popup to close it. Choices stay pending until Save settings.
Tabs are tried in ascending numeric order; the first is the primary
and the others are overflow destinations. Categories may share tabs.
Existing saved single-tab selections are migrated automatically.

Deposit options:
- Minimum item quality (0–5)
- Skip Mythics
- Skip attuned BoEs (fully attuned specific item-link/variant)
- Skip attuned variant BoEs (any attuned variant on the account)
The BoE rules are OFF by default and deliberately skip items whose
original binding or needed attunement information cannot be confirmed.
Transfer interval: 10–200 ms (80 ms default); under 50 ms is experimental.
Save and Revert buttons are anchored inside the settings panel.
Guild-tab choices and deposit rules are saved per guild and realm.

TRANSFERS — ENGINE UNCHANGED FROM 1.2.1
Individual Deposit: selected guild tabs in order, using the current
open tab as a fallback when all assigned tabs cannot take the item.
Without selected tabs, Individual Deposit uses the open tab.
Deposit All: only designated tabs; skips categories without transferable
items. Overflow tabs are only visited if eligible items remain and the
current tab cannot accommodate them. Never uses unassigned fallback tabs.
Individual Withdraw: current bank tab only. Weapons require eligibility
for the current character.
Withdraw All: guild bank only; scans open tab first, then other accessible
tabs; withdraws only equipment currently attunable by this character.
Regular bank and Jeeves support, optional Mythic/BoE deposit filtering,
and tab-overflow safety are retained.
The addon waits for pending source changes between tab switches; if a
move is unconfirmed for three seconds, the batch stops rather than
risking a duplicate attempt. Bank responses may lag or be throttled.

COMMANDS
/ggm              Open settings
/ggm window       Toggle transfer window
/ggm all          Deposit All
/ggm withdrawall  Withdraw All
/ggm tabs         Show assigned guild tabs
/ggm debug        Debug bank detection

VALIDATION STATUS
The transfer-engine regression suite passes in an offline WoW mock.
The exact appearance at different UI scales, server-specific responses,
and addon memory usage should be checked in the live Synastria client.
Back up SavedVariables before updating; begin with 80 ms and inexpensive
items when validating a new installation.

CREDITS AND LICENSING
The bundled MaterialCraftUI Style.lua and Classic skin are from
MaterialCraftUI by iExpulsion (MIT); see MATERIALCRAFTUI_LICENSE.txt.
No other MaterialCraftUI skins or artwork are bundled.
See THIRD_PARTY_NOTICES.txt for OmniInventory attribution.
The eight custom textures (All, Bank, Inventory, Cloth, Leather, Mail,
Plate, Weapons) come from artwork supplied by the addon author. They
are resized and converted into WoW-compatible .tga files only.

PRE-TEST ADVERSARIAL AUDIT (1.3.1)
The first 1.3.0 UI rebuild was reviewed against the bundled MaterialCraftUI
Classic source and a separate failure-injection test. A rare partial
settings-construction failure could leave an incomplete Interface > AddOns
page registered on subsequent attempts. This build registers the page only
after all controls have been created successfully. The bug was reproduced
in v1.3.0 and the corrected build passes the same test.
Removed an unused legacy Blizzard button constructor and an unused popup
variable from the UI rebuild. No bank-transfer, attunement, tab-routing,
SavedVariables key, texture, or MaterialCraftUI library behavior was changed.
The visual layouts still require an in-client check at the player's UI scale.

UI REFINEMENT (1.3.2)
- Compact layout: feathered additive glow around full selected-direction and action buttons;
  inactive direction has no outline. Window height reduced.
- Icons: original eight uploaded artworks unchanged. Glow is a transparent-center
  additive nine-slice surrounding each frame, not drawn on the item image.
  Both separators match and spaces are reduced.
- Settings: Mythic and both BoE exclusions aligned vertically under minimum quality.
  Slightly expanded explanatory tooltips.
- All bank transfers and saved settings use the pre-existing code paths.

UI TWEAKS (1.3.3)
- Tab selector buttons aligned vertically with Cloth/Leather/Mail/Plate/Weapons labels.
- Renamed three deposit-option labels and shortened tooltips as requested.
- New bottom-right corner resize grip. Resizes the entire floating window,
  not individual controls, to preserve layout ratios. Scale (0.65–1.65) is
  shared across all characters on the account and restored across relogs.
- The bank transfer logic, MaterialCraftUI Classic skin, icon art, and
  existing guild assignments are unchanged.

PERFORMANCE/MEMORY AUDIT (1.3.4)
- Kept the existing guild/personal-bank transfer engine and the MaterialCraftUI
  Classic framework intact, including deliberate live-bank detection.
- Each of the seven square icon buttons now uses one transparent-center
  additive glow texture instead of eight; 49 fewer retained texture regions.
  Rectangular buttons retain their 9-slice feathered borders.
- Reduced the bounded, recomputable BoE template cache from 512 to 256 entries.
- Stopped allocating temporary dimension and icon-button tables on redraw.
- Resize dragging reuses one callback rather than allocating one per drag.
- In a simulated UI environment, the build created 309 rather than 358
  textures. This is not a measured WoW Lua-memory reduction.
- Verify the icon border appearance at your UI scale. The seven icon-button
  border glows use the same original texture, now as a single square region.
- Do not compare the WoW addon-memory counter with texture file sizes;
  game textures have different runtime and graphics-memory accounting.

ACCOUNT-WIDE UI PREFERENCES (1.3.5)
Floating-window layout (Full/Compact/Icons), Deposit/Withdraw direction,
window position, and corner-drag scale are now shared by every character
on this WoW account (GearMoverDB.uiGlobal). On the first login after an
upgrade, the current character's saved UI choices are copied into the
account-wide settings, or another existing character's settings are used
if none are saved for the current character. Older character UI records
are then removed. The first migrated layout becomes the shared layout
for everyone, and later changes by any character update it.
Guild-bank tab assignments and deposit rules still remain separate per
guild/realm; they are already shared across characters in that guild.
Transfer speed continues to be shared account-wide.
