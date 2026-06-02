## Qwen-TTS

**支持的模型**：仅支持千问3-TTS-Instruct-Flash系列模型。

**使用方式**：通过 `instruction` 参数指定指令内容。

**指令文本支持的语言**：仅支持中文和英文。

**指令文本长度限制**：不超过 1600 Token。

**适用场景**：

-   有声书和广播剧配音
    
-   广告和宣传片配音
    
-   游戏角色和动画配音
    
-   情感化的智能语音助手
    
-   纪录片和新闻播报
    

**如何编写高质量的声音描述**：

-   **核心原则**：
    
    1.  **具体而非模糊**：使用描绘声音特质的词语，如“低沉”、“清脆”、“语速偏快”，避免“好听”、“普通”等主观或模糊的表述。
        
    2.  **多维而非单一**：好的描述通常涵盖多个维度（如性别、年龄、情感等）。仅写“女声”过于宽泛，难以生成有特色的音色。
        
    3.  **客观而非主观**：聚焦声音的物理和感知特征。例如，用”音调偏高，带有活力“代替”我最喜欢的声音”。
        
    4.  **原创而非模仿**：描述声音的特质，而非要求模仿特定人物（如名人、演员）。模型不支持模仿，且可能涉及版权风险。
        
    5.  **简洁而非冗余**：确保每个词都有明确作用，避免重复的同义词或无意义的修饰。
        
-   **描述维度参考**：
    
    建议组合以下维度描述声音，维度越丰富，生成效果越精准。
    
    | **维度** | **描述示例** |
    | --- | --- |
    | 性别  | 男性、女性、中性 |
    | 年龄  | 儿童（5-12 岁）、青少年（13-18 岁）、青年（19-35 岁）、中年（36-55 岁）、老年（55 岁以上） |
    | 音调  | 高音、中音、低音、偏高、偏低 |
    | 语速  | 快速、中速、缓慢、偏快、偏慢 |
    | 情感  | 开朗、沉稳、温柔、严肃、活泼、冷静、治愈 |
    | 特点  | 有磁性、清脆、沙哑、圆润、甜美、浑厚、有力 |
    | 用途  | 新闻播报、广告配音、有声书、动画角色、语音助手、纪录片解说 |
    
-   **示例**：
    
    -   标准播音风格：吐字清晰精准，字正腔圆
        
    -   年轻活泼的女性声音，语速较快，带有明显的上扬语调，适合介绍时尚产品
        
    -   沉稳的中年男性，语速缓慢，音色低沉有磁性，适合朗读新闻或纪录片解说
        
    -   温柔知性的女性，30 岁左右，语调平和，适合有声书朗读
        
    -   可爱的儿童声音，大约 8 岁女孩，说话略带稚气，适合动画角色配音
        

## **适用范围**

**不同**[**服务部署范围**](https://help.aliyun.com/zh/model-studio/regions/)**支持的模型不同**：

## 中国内地

服务部署范围为[中国内地](https://help.aliyun.com/zh/model-studio/regions/#080da663a75xh)时，模型推理计算资源仅限于中国内地；静态数据存储于您所选的地域。该部署范围支持的地域：华北2（北京）。

调用以下模型时，请选择北京地域的[API Key](https://bailian.console.aliyun.com/?tab=model#/api-key)：

-   **CosyVoice**：cosyvoice-v3.5-plus、cosyvoice-v3.5-flash、cosyvoice-v3-plus、cosyvoice-v3-flash、cosyvoice-v2
    
-   **MiniMax**：MiniMax/speech-2.8-hd、MiniMax/speech-02-hd、MiniMax/speech-2.8-turbo、MiniMax/speech-02-turbo
    
-   **Qwen-TTS**：
    
    -   **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash（稳定版，当前等同qwen3-tts-instruct-flash-2026-01-26）、qwen3-tts-instruct-flash-2026-01-26（最新快照版）
        
    -   **千问3-TTS-VD****：**qwen3-tts-vd-2026-01-26（最新快照版）
        
    -   **千问3-TTS-VC****：**qwen3-tts-vc-2026-01-22（最新快照版）
        
    -   **千问3-TTS-Flash**：qwen3-tts-flash（稳定版，当前等同qwen3-tts-flash-2025-11-27）、qwen3-tts-flash-2025-11-27、qwen3-tts-flash-2025-09-18
        
    -   **千问-TTS**：qwen-tts（稳定版，当前等同qwen-tts-2025-04-10）、qwen-tts-latest（最新版，当前等同qwen-tts-2025-05-22）、qwen-tts-2025-05-22（快照版）、qwen-tts-2025-04-10（快照版）
        

## 国际

服务部署范围为[国际](https://help.aliyun.com/zh/model-studio/regions/#080da663a75xh)时，模型推理计算资源在全球范围内动态调度（不含中国内地）；静态数据存储于您所选的地域。该部署范围支持的地域：新加坡。

调用以下模型时，请选择新加坡地域的[API Key](https://modelstudio.console.aliyun.com/?tab=dashboard#/api-key)：

-   **Qwen-TTS**：
    
    -   **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash（稳定版，当前等同qwen3-tts-instruct-flash-2026-01-26）、qwen3-tts-instruct-flash-2026-01-26（最新快照版）
        
    -   **千问3-TTS-VD****：**qwen3-tts-vd-2026-01-26（最新快照版）
        
    -   **千问3-TTS-VC****：**qwen3-tts-vc-2026-01-22（最新快照版）
        
    -   **千问3-TTS-Flash**：qwen3-tts-flash（稳定版，当前等同qwen3-tts-flash-2025-11-27）、qwen3-tts-flash-2025-11-27、qwen3-tts-flash-2025-09-18
        

## **支持的系统音色**

不同模型支持的音色不同。将请求参数 `voice` 设为下表中 **voice 参数**列的值即可。

-   [CosyVoice音色列表](https://help.aliyun.com/zh/model-studio/cosyvoice-voice-list)
    
-   Qwen-TTS音色列表：
    
    | `**voice**`**参数** | **详情** | **支持语种** | **支持模型** |
    | `Cherry` | **音色名**：芊悦 **描述**：阳光积极、亲切自然小姐姐（女性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27、qwen3-tts-flash-2025-09-18 - **千问-TTS**：qwen-tts、qwen-tts-2025-04-10、qwen-tts-latest、qwen-tts-2025-05-22 |
    | `Serena` | **音色名**：苏瑶 **描述**：温柔小姐姐（女性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 - **千问-TTS**：qwen-tts、qwen-tts-2025-04-10、qwen-tts-latest、qwen-tts-2025-05-22 |
    | `Ethan` | **音色名**：晨煦 **描述**：标准普通话，带部分北方口音。阳光、温暖、活力、朝气（男性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27、qwen3-tts-flash-2025-09-18 - **千问-TTS**：qwen-tts、qwen-tts-2025-04-10、qwen-tts-latest、qwen-tts-2025-05-22 |
    | `Chelsie` | **音色名**：千雪 **描述**：二次元虚拟女友（女性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 - **千问-TTS**：qwen-tts、qwen-tts-2025-04-10、qwen-tts-latest、qwen-tts-2025-05-22 |
    | `Momo` | **音色名**：茉兔 **描述**：撒娇搞怪，逗你开心（女性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Vivian` | **音色名**：十三 **描述**：拽拽的、可爱的小暴躁（女性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Moon` | **音色名**：月白 **描述**：率性帅气的月白（男性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Maia` | **音色名**：四月 **描述**：知性与温柔的碰撞（女性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Kai` | **音色名**：凯 **描述**：耳朵的一场SPA（男性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Nofish` | **音色名**：不吃鱼 **描述**：不会翘舌音的设计师（男性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27、qwen3-tts-flash-2025-09-18 |
    | `Bella` | **音色名**：萌宝 **描述**：喝酒不打醉拳的小萝莉（女性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Jennifer` | **音色名**：詹妮弗 **描述**：品牌级、电影质感般美语女声（女性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27、qwen3-tts-flash-2025-09-18 |
    | `Ryan` | **音色名**：甜茶 **描述**：节奏拉满，戏感炸裂，真实与张力共舞（男性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27、qwen3-tts-flash-2025-09-18 |
    | `Katerina` | **音色名**：卡捷琳娜 **描述**：御姐音色，韵律回味十足（女性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27、qwen3-tts-flash-2025-09-18 |
    | `Aiden` | **音色名**：艾登 **描述**：精通厨艺的美语大男孩（男性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Eldric Sage` | **音色名**：沧明子 **描述**：沉稳睿智的老者，沧桑如松却心明如镜（男性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Mia` | **音色名**：乖小妹 **描述**：温顺如春水，乖巧如初雪（女性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Mochi` | **音色名**：沙小弥 **描述**：聪明伶俐的小大人，童真未泯却早慧如禅（男性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Bellona` | **音色名**：燕铮莺 **描述**：声音洪亮，吐字清晰，人物鲜活，听得人热血沸腾；金戈铁马入梦来，字正腔圆间尽显千面人声的江湖（女性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Vincent` | **音色名**：田叔 **描述**：一口独特的沙哑烟嗓，一开口便道尽了千军万马与江湖豪情（男性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Bunny` | **音色名**：萌小姬 **描述**：“萌属性”爆棚的小萝莉（女性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Neil` | **音色名**：阿闻 **描述**：平直的基线语调，字正腔圆的咬字发音，这就是最专业的新闻主持人（男性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Elias` | **音色名**：墨讲师 **描述**：既保持学科严谨性，又通过叙事技巧将复杂知识转化为可消化的认知模块（女性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27、qwen3-tts-flash-2025-09-18 |
    | `Arthur` | **音色名**：徐大爷 **描述**：被岁月和旱烟浸泡过的质朴嗓音，不疾不徐地摇开了满村的奇闻异事（男性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Nini` | **音色名**：邻家妹妹 **描述**：糯米糍一样又软又黏的嗓音，那一声声拉长了的“哥哥”，甜得能把人的骨头都叫酥了（女性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Seren` | **音色名**：小婉 **描述**：温和舒缓的声线，助你更快地进入睡眠，晚安，好梦（女性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Pip` | **音色名**：顽屁小孩 **描述**：调皮捣蛋却充满童真的他来了，这是你记忆中的小新吗（男性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Stella` | **音色名**：少女阿月 **描述**：平时是甜到发腻的迷糊少女音，但在喊出“代表月亮消灭你”时，瞬间充满不容置疑的爱与正义（女性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Instruct-Flash**：qwen3-tts-instruct-flash、qwen3-tts-instruct-flash-2026-01-26 - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Bodega` | **音色名**：博德加 **描述**：热情的西班牙大叔（男性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Sonrisa` | **音色名**：索尼莎 **描述**：热情开朗的拉美大姐（女性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Alek` | **音色名**：阿列克 **描述**：一开口，是战斗民族的冷，也是毛呢大衣下的暖（男性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Dolce` | **音色名**：多尔切 **描述**：慵懒的意大利大叔（男性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Sohee` | **音色名**：素熙 **描述**：温柔开朗，情绪丰富的韩国欧尼（女性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Ono Anna` | **音色名**：小野杏 **描述**：鬼灵精怪的青梅竹马（女性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Lenn` | **音色名**：莱恩 **描述**：理性是底色，叛逆藏在细节里——穿西装也听后朋克的德国青年（男性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Emilien` | **音色名**：埃米尔安 **描述**：浪漫的法国大哥哥（男性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Andre` | **音色名**：安德雷 **描述**：声音磁性，自然舒服、沉稳男生（男性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Radio Gol` | **音色名**：拉迪奥·戈尔 **描述**：足球诗人Rádio Gol！今天我要用名字为你们解说足球（男性） | 中文（普通话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27 |
    | `Jada` | **音色名**：上海-阿珍 **描述**：风风火火的沪上阿姐（女性） | 中文（上海话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27、qwen3-tts-flash-2025-09-18 - **千问-TTS**：qwen-tts-latest、qwen-tts-2025-05-22 |
    | `Dylan` | **音色名**：北京-晓东 **描述**：北京胡同里长大的少年（男性） | 中文（北京话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27、qwen3-tts-flash-2025-09-18 - **千问-TTS**：qwen-tts-latest、qwen-tts-2025-05-22 |
    | `Li` | **音色名**：南京-老李 **描述**：耐心的瑜伽老师（男性） | 中文（南京话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27、qwen3-tts-flash-2025-09-18 |
    | `Marcus` | **音色名**：陕西-秦川 **描述**：面宽话短，心实声沉——老陕的味道（男性） | 中文（陕西话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27、qwen3-tts-flash-2025-09-18 |
    | `Roy` | **音色名**：闽南-阿杰 **描述**：诙谐直爽、市井活泼的台湾哥仔形象（男性） | 中文（闽南语）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27、qwen3-tts-flash-2025-09-18 |
    | `Peter` | **音色名**：天津-李彼得 **描述**：天津相声，专业捧哏（男性） | 中文（天津话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27、qwen3-tts-flash-2025-09-18 |
    | `Sunny` | **音色名**：四川-晴儿 **描述**：甜到你心里的川妹子（女性） | 中文（四川话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27、qwen3-tts-flash-2025-09-18 - **千问-TTS**：qwen-tts-latest、qwen-tts-2025-05-22 |
    | `Eric` | **音色名**：四川-程川 **描述**：一个跳脱市井的四川成都男子（男性） | 中文（四川话）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27、qwen3-tts-flash-2025-09-18 |
    | `Rocky` | **音色名**：粤语-阿强 **描述**：幽默风趣的阿强，在线陪聊（男性） | 中文（粤语）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27、qwen3-tts-flash-2025-09-18 |
    | `Kiki` | **音色名**：粤语-阿清 **描述**：甜美的港妹闺蜜（女性） | 中文（粤语）、英语、法语、德语、俄语、意大利语、西班牙语、葡萄牙语、日语、韩语 | - **千问3-TTS-Flash**：qwen3-tts-flash、qwen3-tts-flash-2025-11-27、qwen3-tts-flash-2025-09-18 |
    

## **API 参考**

-   [非实时语音合成-CosyVoice API参考](https://help.aliyun.com/zh/model-studio/non-realtime-cosyvoice-api/)
    
-   [非实时语音合成-千问API参考](https://help.aliyun.com/zh/model-studio/qwen-tts-api)
    
-   [非实时语音合成-MiniMax API 参考](https://help.aliyun.com/zh/model-studio/minimax-speech-synthesis/)
    

## **常见问题**

### **Q：音频文件链接的有效期是多久？**

A：音频文件链接在生成后 24 小时内有效，过期后需重新调用接口生成。

 span.aliyun-docs-icon { color: transparent !important; font-size: 0 !important; } span.aliyun-docs-icon:before { color: black; font-size: 16px; } span.aliyun-docs-icon.icon-size-20:before { font-size: 20px; } span.aliyun-docs-icon.icon-size-22:before { font-size: 22px; } span.aliyun-docs-icon.icon-size-24:before { font-size: 24px; } span.aliyun-docs-icon.icon-size-26:before { font-size: 26px; } span.aliyun-docs-icon.icon-size-28:before { font-size: 28px; }