# Web UI P3 — Hub and solo departure

Implemented only in `feature/web-ui-v0-6`.

- Registered `WebHubHome` and `WebSoloDeparture` on the P1 landscape `WebUIShell`.
- Title Continue/New Game displays Web hub for Hub phase. Existing Battle/route/reward resumes remain on the original controller.
- Web home lists equipment, forge, merchant and solo; navigation is **one tap**. Equipment/forge/merchant deliberately fall back to existing functional UI until P4. Legacy hub navigation has a Web-home return action.
- Web solo displays six Regions, B01-B04, equipped six slots, generated deck count/HP, Seed and Run Gold 100G.
- Region, Stage and Departure use the shared first-tap preview / second-tap confirmation `WebSelectionGate`; no write on preview. Locked Regions and Bosses disabled.
- Selected region/stage remain presentation-only until **final departure confirmation**. Final confirm invokes unchanged `CampaignController.select_region` if needed, then `begin(seed, stage)` once.
- The resulting phase is Route, displayed on the legacy adventure screen until P5. No gameplay/economy/save format changes.
- Existing Windows UI and the live Pages `main` branch are untouched.
- P3 regression tests check no state or save mutations on preview and confirmed start transitions.
