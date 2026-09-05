---
title: 存档系统
order: 2
---

# 存档系统

默认对话模板提供快速保存、快速读取和存档面板。槽位 `0` 用作快速存档；默认共有 20 个槽位，编号为 `0`–`19`。

## 使用方法

先取得默认对话模板中的对话管理器，例如：

```gdscript
@export var dialogue_manager: KonadoDialogueManager
```

### 快速保存

```gdscript
# 快速保存到槽位 0
dialogue_manager.save_game(0)
```
### 快速读取
```gdscript
# 从槽位 0 快速加载
dialogue_manager.load_game(0)
```

### 保存游戏

```gdscript
# 保存到指定槽位
dialogue_manager.save_game(1)  # 保存到 1 号槽位
```

### 加载游戏

```gdscript
# 从指定槽位加载
dialogue_manager.load_game(1)  # 从 1 号槽位加载
```

### 删除存档

```gdscript
# 删除指定槽位的存档
dialogue_manager.delete_save(1)  # 删除 1 号槽位的存档
```

### 获取存档信息

```gdscript
# 获取指定槽位的存档信息
var save_info = dialogue_manager.get_save_info(1)
print("存档时间: " + str(save_info.get("save_time", {})))

# 获取所有存档信息
var all_save_infos = dialogue_manager.get_all_save_info()
for i in range(all_save_infos.size()):
    if all_save_infos[i].get("exists", false):
        print("存档 " + str(i) + " 存在")
```

## 存档数据结构

Konado 在一个原子执行边界中保存当前指令、临时与持久变量、对话框、角色、背景、相机和音频等运行状态。完整状态必须作为整体保存和恢复，不能选择性关闭其中一部分，否则画面和剧情逻辑可能不一致。

读取时会校验存档格式、编译器 ABI、剧本指纹和指令标识。剧本结构发生变化而无法准确恢复时，加载会明确失败，不会静默跳转到错误剧情位置。`save_game()`、`load_game()` 和 `delete_save()` 均返回 `bool`，调用方应处理失败结果。

## 存档文件格式

存档保存在 `user://konado_saves/`，文件名为 `[槽位ID].kns`。文件使用带格式版本、长度和 SHA-256 完整性校验的二进制封装；这可以发现损坏或不完整写入，但不属于加密或防篡改安全机制。
