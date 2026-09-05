---
title: セーブシステム
order: 2
---

# セーブシステム

デフォルトの会話テンプレートには、クイックセーブ、クイックロード、セーブスロットパネルが含まれます。スロット `0` はクイックセーブ用です。デフォルトでは `0`～`19` の 20 スロットを使用できます。

## 使用方法

最初に、デフォルト会話テンプレートの会話マネージャーを参照します。

```gdscript
@export var dialogue_manager: KonadoDialogueManager
```

### ゲームを保存

```gdscript
# 指定スロットへ保存
dialogue_manager.save_game(1)  # スロット 1 へ保存
```

### ゲームを読み込み

```gdscript
# 指定スロットから読み込み
dialogue_manager.load_game(1)  # スロット 1 から読み込み
```

### セーブを削除

```gdscript
# 指定スロットのセーブを削除
dialogue_manager.delete_save(1)  # スロット 1 のセーブを削除
```

### セーブ情報を取得

```gdscript
# 指定スロットのセーブ情報を取得
var save_info = dialogue_manager.get_save_info(1)
print("保存時間: " + str(save_info.get("save_time", {})))

# すべてのセーブ情報を取得
var all_save_infos = dialogue_manager.get_all_save_info()
for i in range(all_save_infos.size()):
    if all_save_infos[i].get("exists", false):
        print("セーブ " + str(i) + " が存在します")
```

## セーブデータ構造

Konado は、現在の命令、一時変数と永続変数、会話ボックス、アクター、背景、カメラ、オーディオなどの実行状態を、1 つのアトミックな実行境界として保存します。表示とストーリーの状態が食い違わないよう、完全な状態を一体として保存・復元します。

ロード時にはファイル形式、コンパイラー ABI、スクリプト指紋、命令 ID を検証します。変更後のスクリプトへ正確に復元できない場合は、誤った位置へ進まずロードに失敗します。`save_game()`、`load_game()`、`delete_save()` は `bool` を返すため、失敗結果を処理してください。

## セーブファイル形式

セーブファイルは `user://konado_saves/` に `[スロットID].kns` として保存されます。形式バージョン、ペイロード長、SHA-256 完全性ダイジェストを含むバイナリ形式です。破損や不完全な書き込みは検出できますが、暗号化や改ざん防止の仕組みではありません。
