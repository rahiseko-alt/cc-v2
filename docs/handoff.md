# handoff（次セッションへの特筆事項 / 3行以内・ロードマップ事項は書かない）

起動スモークjobは毎回クリーンビルドするため quality job より遅い（build 待ちで run 全体が ~1分強）。
CI待ちは in_progress の間ポーリングで確認する（webhook では build 完了/成功が来ない）。
