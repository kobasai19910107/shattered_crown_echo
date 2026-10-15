# Web UI v0.6 / P4 — 装備・倉庫・鍛冶屋・商人

作成: 2026-10-15 / 作業ブランチ: `feature/web-ui-v0-6`。**本番 `main` へのマージ・Pages 公開は行わない。**

## 今回追加した Godot Web UI

| 画面/部品 | 実装 | 保存とリスク対策 |
| --- | --- | --- |
| `web_equipment_detail.gd` | 名前/レアリティ/HP/Socket/抽選属性/特殊効果/付属4カードと個別正式本文、カードのタップ詳細 | 読み取り専用、カード詳細を見るだけで装備を確定しない |
| `web_equipment_warehouse.gd` | 装備部位6区分・倉庫スクロール・装備比較/カード参照 | 装備1回目プレビュー、同一UIDの2回目で `equip(uid)` |
| `web_forge_screen.gd` | 装備HP強化・Socket拡張・ランダム枠2つ再抽選・特殊効果再抽選・分解・再抽選候補A/B/現状維持 | 操作1回目プレビュー、再タップ加工、分解はさらにダイアログ確認。候補の決定も2段階 |
| `web_hub_merchant.gd` | 商人の購入・売却・商品更新、4カード詳細 | 購入2回タップ、売却2回タップ＋ダイアログ、商品更新2回タップ |
| `web_ui_shell.gd` | 施設画面遷移＋鍛冶再抽選保留中の戻る禁止 | `forge_pending` が空になるまで別画面へ移動しない |

## ゲームの正式ロジックを共有

- すべてのHP/価格/所持Gold/素材/装備カード/レアリティ/Socket上限/再抽選回数は **現行の `Region1RunController` と `Step8EquipmentRoller`** を参照する。
- 画面で完結するカード・装備表示は `HubDeckAnalyzer` と `EquipmentSpecialEffectPolicy.summary()` を利用する。
- 操作を確定するまで、ラン・装備・Gold・素材は変化しない。
- 購入では `buy_hub_item(index,expected_uid)`、売却では `sell_hub_item(uid)`、鍛冶では `forge`/`resolve_forge` の既存APIを実行する。
- 商品在庫が未生成の場合に **商人画面の初回オープンで `ensure_hub_shop()` が在庫を生成・保存する既存仕様** は維持する（購入プレビューの保存とは別）。
- 装備中の品物は売却・分解しない。再抽選が未完了ならルート変更を禁止する。
- 確定直前に UID、装備スナップショット、Gold条件を再検証して古い詳細表示からの誤処理を避ける。
- 再抽選の候補・現状維持の確定だけで既に払った費用は戻さない。
- 装備4カード内の詳細タップは単純な読取イベントで、共通の2タップ選択ゲートに入れない。
- 不可逆な売却・分解の確認ウィンドウはキャンセル・閉じる操作でロックが解除され、処理が実行されない。

## 検証

`.github/workflows/web-ui-check.yml` から P1〜P4、Godot import、main-scene smoke、Web export を実行する。P4テストは専用 `user://web_p4_disposable_fixture.json` にのみ保存し、ユーザーのセーブファイルを触らない。

**未完:** iPhone Safari実機での横幅・文字サイズ・Safe Area・ScrollContainer手触り、すべての武器属性カードの表示網羅、鍛冶の稀な無候補ケースの操作性。P6で本番公開前に受入を行う。

## 次のP5

道選択・宝箱/戦闘報酬・イベント/休憩・勝敗/帰還をWeb専用画面化し、すべての選択操作で「先に詳細・次に決定」を維持する。
