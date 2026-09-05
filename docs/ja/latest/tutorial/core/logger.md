---
title: Logger
order: 4
---

# ロガー KonadoLogger

## はじめに

KonadoLogger は Godot Logger の実装を基にしたログモジュールです。ログレベル、ログ形式、ログ出力、ログファイルなどをサポートし、Konado 実行時のログ情報を記録するために使用します。

## ログパス

ログファイルの論理パスは `user://konado_log.log` です。実際のディレクトリは現在の OS とプロジェクト名に応じて Godot が解決し、`OS.get_user_data_dir()` で確認できます。`LOG_FILE_PATH` は組み込み定数のため、保存先を変更する場合はカスタム版プラグインでこの定数を管理してください。

## 画面オーバーレイログ

エラー発生時、会話シーンは画面上にログウィンドウを重ねて表示し、エラー情報を示してゲーム実行を中断します。通常の警告は引き続きログファイルに記録されますが、実行時エラーとして表示されたり、ゲームを中断したりすることはありません。エラーオーバーレイを無効にする場合は、`KonadoDialogueManager` の `enable_overlay_log` プロパティを `false` に設定してください。

## ログコールバック

`KonadoLogger` のインスタンスは `error_caught(msg)` と `message_caught(message, error)` シグナルを送出します。`KonadoDialogueManager` はシーンツリーに入ると内部ロガーを作成して Godot に登録し、`error_caught` で画面オーバーレイを制御します。ロガーはグローバルな自動読み込みではありません。別の `KonadoLogger` を作成するカスタム連携では `OS.add_logger()` で登録し、解放前に `OS.remove_logger()` を呼び出して、重複記録や無効なインスタンスの残留を防いでください。

## 実行時エラー

アトミック命令が失敗すると、`KonadoDialogueManager` は最終エラーを 1 件だけ記録し、`runtime_failure_reported(failure)` シグナルを送出します。`failure` には安定したエラーコード、操作、関連リソース、根本原因、ソースパスと行、命令 ID、オペコード、プログラム位置が含まれ、クラッシュレポートや独自デバッグ UI に利用できます。簡易インターフェースとして `runtime_failed(message, instruction_id, source_line)` も引き続き利用できます。
