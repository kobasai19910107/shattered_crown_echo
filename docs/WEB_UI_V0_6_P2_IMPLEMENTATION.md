# Web UI P2 — Battle implementation (feature branch only)

- Web landscape battle screen displays HP, Mana, Block, active traits, enemy portraits, HP, order, Intent, scrollable hand and standard actions.
- All actual card and enemy targeting inputs delegate to the unchanged main.gd handlers and BattleController; selection alone does not consume resources.
- Self/no-target cards use a second tap on the same card or the Use button; enemy-target cards are confirmed by tapping an enemy. Tap an enemy without a selected attack to inspect its next action.
- Horizontal hand scrolling when 6+ cards. Auto-battle button delegates to current AutoBattlePolicy.
- Campaign present_battle opens the new Web screen; returning to adventure closes it while preserving campaign state. P3 will add the Web hub.
- Added `tests/web_ui_p2_test.gd`; all CI remains isolated on `feature/web-ui-v0-6` without deploying Pages.
- Remaining for later device acceptance: typography at actual iPhone aspect ratios, popup readability, additional card-choice flows, effects/animation fidelity.
