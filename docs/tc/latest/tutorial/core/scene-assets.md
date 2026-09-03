---
title: 場景化資源
order: 8
---

# 場景化資源

角色與背景項目現在參照 `PackedScene`。場景中可以放置圖片、影片、Spine、Live2D、shader 或自訂節點。

角色場景應繼承 `KonadoCharacterSceneBase`，並覆寫 `_apply_status(resolved_status_name, original_status_name)`；能驗證狀態名稱時也應覆寫 `_has_status`。延遲轉場可能在接受請求與最終套用時分別查詢，因此 `_has_status` 必須無副作用且具冪等性。能安全提供純紋理的場景可同時實作 `_get_current_status_transition_frame` 與 `_get_status_transition_frame`，透過 `KonadoCharacterTransitionFrame` 進行預乘 Alpha 交融。無法提供無副作用影格的 Live2D、Spine、影片和自訂場景會自動使用淡出、套用狀態、淡入的安全路徑；兩條路徑都不會複製角色場景。詳細設定請參閱[演員切換狀態](../script/actor/actor-change-state.md)。舞台動作應放在 `KonadoActorMotionLayer` 場景，其動畫名稱需與 KS 動作名稱一致。

每次要求狀態影格都必須回傳新建的獨立影格，不可在兩個轉場端點之間重複使用並改寫同一個可變物件。

背景場景應繼承 `KonadoBackgroundSceneBase`。如需使用鏡頭指令，請加入名稱唯一的 `KonadoCameraMarker`。這些節點只儲存目標機位的位置與縮放，實際畫面由對話範本中的相機繪製；請勿用 `KonadoCameraMarker` 取代自訂的繪製相機。內建轉場由 `KonadoBackgroundTransitionLayer` 處理，預設會透過 `SubViewport` 擷取完整場景。只有最終畫面與單張未修改的原始紋理完全一致時，才能選擇 `DIRECT_TEXTURE`；使用版面配置、變換、鏡頭、動畫、材質、染色或多個可繪製節點的背景必須保留 `VIEWPORT_CAPTURE`。
