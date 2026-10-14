# iPhone Safari Web UI correction (2026-10-15)
This change applies to the **web repo** only, not the original Windows ZIP.

- Godot UI previously relied on system-installed CJK fonts. iPhone Safari Web export shows Japanese characters as empty boxes when the Web package does not ship glyphs.
- The GitHub Actions build now downloads official Noto Sans JP under its SIL Open Font License, places the font inside the temporary build workspace, and configures `gui/theme/custom_font` *before Godot imports the project*. The font is not committed to repository history.
- Godot stretch aspect is now `expand` so that the canvas can adapt to widescreen phone aspect ratios instead of retaining large letterbox bars.
- Default GUI theme scale is 1.25 for initial legibility improvement; the pre-existing 1280×900 PC layout still needs a separate touch UI refactor.
- In iPhone Safari, rotate to **landscape** and reload once after the new deployment; if the old version appears, refresh without cached content.

Font source: https://github.com/google/fonts/tree/main/ofl/notosansjp
Font license: https://github.com/google/fonts/blob/main/ofl/notosansjp/OFL.txt
