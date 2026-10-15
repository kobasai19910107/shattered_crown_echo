# P1 — Web UI common layer

- Branch: `feature/web-ui-v0-6`; production `main` untouched.
- `WebSelectionGate`: first tap previews; second tap of same stable choice ID emits one commit request and locks until acknowledged. Changing candidates is preview only; cancel never commits.
- `WebUIRouter`: routes and back stack only, no campaign side effects.
- `WebUIShell`: landscape orientation hint, touch-friendly top navigation and registered screen host. **Hidden/inactive** in P1; P2+ will register battle and hub screens.
- Main scene instantiates hidden shell on Web only. Existing gameplay flow is unchanged.
- A dedicated P1 workflow runs tests, startup smoke and Web export from this feature branch; uploaded artifact is **not deployed to GitHub Pages**.
- Combat targeting is intentionally not redirected through the generic two-tap system.
- No economy/saves/card effects changed.
