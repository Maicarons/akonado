---
title: 会話ボックスのカスタマイズ
order: 4
---

# 会話インターフェースのカスタマイズ

## 紹介

会話インターフェースをカスタマイズする場合は、使用するテンプレートシーンを `res://ui/dialogue/` などプロジェクト側のディレクトリへコピーし、その複製または Godot のカスタムテーマを編集してください。

`res://addons/konado/` 内のファイルを直接編集しないでください。プラグイン更新時にプラグインディレクトリが置き換わります。プロジェクト側の複製は Konado を更新しても保持されます。

## テンプレートファイルの編集

`res://addons/konado/templates/` には組み込み会話テンプレートがあります。必要な `.tscn` をプロジェクトへコピーし、会話シーンでその複製をインスタンス化して、含まれる `KonadoDialogueBox` ノードを `KonadoDialogueManager` の `dialogue_box` プロパティへ割り当てます。

通常はノード上のスクリプトを変更せず、ノードのプロパティを変更してカスタマイズすることを推奨します。

## 表示 API

`KonadoDialogueBox` は一時的な非表示と、内容を破棄する非表示を別の API として提供します。

```gdscript
dialogue_box.hide_dialogue_box()
dialogue_box.hide_dialogue_box_with_duration(0.5)

dialogue_box.dismiss_dialogue_box()
dialogue_box.dismiss_dialogue_box_with_duration(0.5)
```

`hide_dialogue_box*()` は現在の話者名と台詞を保持するため、後で再表示する場合に使用します。`dismiss_dialogue_box*()` は非表示アニメーションの完了後に内容を消去するため、現在の会話内容を終了する場合に使用します。KonadoScript の `hidetextbox` 命令は後者の動作を使用します。

## UI レイヤーの規約

シーンツリーの順序によって全画面 UI が互いに隠れないよう、組み込み UI では次の `CanvasLayer.layer` 値を使用します。

| レイヤー | 用途 |
|----------|------|
| `1` | ステージ、背景、演出コンテンツ |
| `10` | 会話ボックス、選択肢、会話ツールバー |
| `50` | セーブ画面 |
| `100` | 設定や実績などのモーダルパネル |
| `110` | 実績解除などの一時的な通知 |
| `120` | すべての組み込み UI より前面に表示する実行時エラー |

カスタム UI は用途に応じた範囲へ配置してください。システムエラーを覆う必要がない限り、`120` 以上は使用しないでください。実績パネルと通知のレイヤーは `KonadoAchievements.panel_layer` と `popup_layer` でも調整できます。

## ボイス進行表示のカスタマイズ

通常の会話行にボイスタグがあり、音声を再生している間は、会話ボックスに再生進行が表示されます。ボイスがない、リソースを解決できない、または再生が終了した場合は自動的に非表示になります。不要な場合は `KonadoDialogueBox` ノードの `show_voice_progress` を無効にしてください。

組み込みコンポーネントの元ファイルは `res://addons/konado/templates/default/voice_progress_display.tscn` です。色、角丸、サイズ、ノード構造を変更する前にプロジェクトへコピーし、カスタマイズした会話ボックスからその複製を参照してください。完全に置き換える場合は次のインターフェースを維持します。

```gdscript
func set_progress(current: float, total: float) -> void
func hide_progress() -> void
```
