# iPhone battle touch layout repair

Web layout only; original Windows ZIP is unchanged.
- Scrollable battle container permits accessing the hand/turn buttons on short landscape screens.
- Hide Web-only nonessential debug/navigation panels and desktop-only hover-preview/telemetry rows.
- Compact enemy portraits, player sidebar, and hand height. Card hand remains horizontally scrollable.
- Add a touch-accessible **カード詳細** button for the selected card.
- Correct Region 1 monster crop coordinates after downsampling the source sprite sheet from 1536×1024 to 1024×683.
- All card effects, victory rules, battle state and save data remain untouched.
- Test on iPhone: select card, tap enemy, open detail, horizontal hand scroll, end turn, hub navigation, and monster art.
