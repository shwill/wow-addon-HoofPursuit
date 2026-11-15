# PlainsTacho

A completely unnecessary wooden speedometer for the Tauren racial **Plainsrunning** (Ebenenlaufen).
While you run, the buff stacks up to 30 times, +2% movement speed per stack (up to +60%). PlainsTacho shows your speed bonus (0-60%) as a needle on a carved wooden dial:

- When the first stack appears, the gauge slams onto the screen: it drops in from "above the camera", shrinking while it fades in, hits its spot with a bounce and the needle jumps from the impact.
- When you've been standing for a while, it tips over backwards and disappears.

- Each new stack makes the needle click forward one notch, with a little overshoot and a click sound.
- Losing stacks makes it click back down: several in quick succession when you get hit, slowly when you stand still.
- The faster you run, the more the needle trembles and the dial rumbles, sways and bumps. At 30 stacks the red zone glows.

## How it gets its data

- Stacks: `C_UnitAuras.GetPlayerAuraBySpellID(1299038)`, polled 10 times a second while the gauge is visible.
- Speed: `GetUnitSpeed("player")`. If the client hides the value (secret value), the shake is driven by the stack count instead.

## Commands

| Command | Effect |
|---------|--------|
| `/tacho` | Show current stacks, speed and mode |
| `/tacho lock` | Lock or unlock the gauge (drag it with the left mouse button while unlocked) |
| `/tacho size <px>` | Gauge size in pixels (80-600, default 200) |
| `/tacho auto` | Slam in with the first stack, fade out after 4 s without stacks or movement (default) |
| `/tacho on` / `/tacho off` | Always show / hide |
| `/tacho sound` | Turn the click sound on or off |
| `/tacho test` | 15 s demo: slam in, build up to 30, take a hit, stand still, fade out |
| `/tacho pop` | Just the animations: slam in, hold 1 s, tip over |
| `/tacho reset` | Reset position, size and settings |

## Caveats

- Tauren only. On any other race, the addon does nothing and disables itself for that character (re-enable it in the AddOn list).
- Settings are saved per character.

## Install

Copy the `PlainsTacho` folder into `World of Warcraft/_forever_/Interface/AddOns/` and restart the game.

Source: https://github.com/shwill/wow-addon-PlainsTacho
