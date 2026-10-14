# Web-only UI readability adjustment
The iPhone landscape screenshot showed a readable but very small PC UI, plus a non-scrollable
hub page clipped on short landscape screens.

- Web project virtual dimensions: **960 × 540**, aspect `expand`.
- Hub and all campaign pages now scroll on Web; Windows Godot behavior unchanged in the original ZIP.
- Tap-target height and hub navigation button size are increased for Web.
- A high-contrast text theme is applied on Web while preserving explicit card/effect colors.
- **Not yet a complete iPhone UI redesign**; equipment panel and battle card arrangement still require device testing.

Testing: Godot import + headless smoke + Web export in GitHub Actions, followed by actual iPhone screenshot and touch tests.
