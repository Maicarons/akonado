---
title: カメラ移動
order: 1
---

# カメラ移動

```text
cam move <camera_id> [none|linear|ease_in_out] [秒]
```

現在の背景にある一意な名前の `KonadoCameraMarker` へ移動します。`KonadoCameraMarker` は目標位置とズームを保存するだけで、シーン自体は描画しません。省略または `none` は即時移動、アニメーションの既定時間は 1 秒です。
