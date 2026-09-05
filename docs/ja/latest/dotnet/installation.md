---
title: インストール
order: 1
---

# インストール

## 基本依存関係

1. Konado プラグインをインストールします（必須）
2. Godot .NET 4.7.1 以降
3. プロジェクトを Godot .NET エディターで開いてください。通常版の Godot エディターでは C# アドオンスクリプトをコンパイルまたは読み込みできません。

## インストール手順

1. konado_dotnet プラグインを Godot プロジェクトの `addons` ディレクトリへ展開します
2. `addons/konado` のメインプラグインも存在することを確認します
3. Godot エディターで `Project -> Project Settings -> Plugins` を開き、先に `Konado` を有効化します
4. C# プロジェクトをビルドし、MSBuild エラーがないことを確認します
5. `Konado.NET` プラグインを有効化します
6. プロジェクトを開き直し、自動読み込みノードと C# スクリプト状態を更新します

## 初回有効化時のよくあるエラー

C# プロジェクトをまだビルドしていない場合、初回有効化時に次のエラーが出ることがあります。

```text
Unable to load addon script from path: 'res://addons/konado_dotnet/editor/KonadoDotNetPlugin.cs'.
```

Godot .NET エディターでプロジェクトをビルドし、開き直してから再度有効化してください。

## 有効化の順序

Konado.NET は Konado 本体プラグインに依存します。次の順序で有効化してください。

1. `Konado` を有効化
2. C# プロジェクトをビルド
3. `Konado.NET` を有効化

Konado.NET を先に有効化した場合は本体プラグインの状態を確認し、本体が無効な間は API 自動読み込みノードを登録しません。

## シーン要件

`DialogueManagerApi` には、完全な公開 API 契約を満たす `KonadoDialogueManager`
ノードが必要です。ノードがシーンツリーへ追加されると自動的にバインドされ、
ノード名には依存しません。

複数の会話マネージャーがある場合は手動でバインドしてください。

```csharp
using Godot;

var manager = GetNode<Node>("UI/KonadoDialogueManager");
Konado.Runtime.Api.KonadoApi.DialogueManagerApi?.BindDialogueManager(manager);
```
