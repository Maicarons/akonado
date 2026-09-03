---
title: シーン形式のリソース
order: 8
---

# シーン形式のリソース

キャラクターと背景は `PackedScene` を参照します。シーンには画像、動画、Spine、Live2D、シェーダー、独自ノードを配置できます。

キャラクターシーンは `KonadoCharacterSceneBase` を継承し、`_apply_status(resolved_status_name, original_status_name)` をオーバーライドします。状態名を検証できる場合は `_has_status` も実装します。遅延トランジションでは要求の受付時と最終適用時に確認されるため、`_has_status` は副作用がなく冪等でなければなりません。純粋なテクスチャを安全に提供できるシーンは `_get_current_status_transition_frame` と `_get_status_transition_frame` の両方を実装し、`KonadoCharacterTransitionFrame` によるプリマルチプライド Alpha ブレンドを利用できます。副作用のないフレームを提供できない Live2D、Spine、動画、独自シーンは安全なフェードアウト、状態適用、フェードインへ自動的にフォールバックします。どちらの経路もキャラクターシーンを複製しません。設定については[アクター状態の切り替え](../script/actor/actor-change-state.md)を参照してください。舞台アニメーションには `KonadoActorMotionLayer` を使用します。

状態フレームの各呼び出しでは新しい独立したフレームを返し、両端で同じ可変フレームを再利用しないでください。

背景シーンは `KonadoBackgroundSceneBase` を継承します。カメラ命令を使う場合は、一意な名前の `KonadoCameraMarker` を追加してください。このノードは目標位置とズームだけを保持し、実際の描画はダイアログテンプレートのカメラが行います。独自の描画用カメラを `KonadoCameraMarker` に置き換えないでください。組み込みトランジションは `KonadoBackgroundTransitionLayer` が処理し、デフォルトでは `SubViewport` でシーン全体をキャプチャします。最終表示が未加工の単一ソーステクスチャと完全に一致する場合に限り `DIRECT_TEXTURE` を選択できます。レイアウト、変形、カメラ、アニメーション、マテリアル、色調変更、複数の描画ノードを使用する背景では `VIEWPORT_CAPTURE` を維持してください。
