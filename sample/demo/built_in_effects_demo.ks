choice "人物动作" -> goto_ks5

choice "背景过渡" -> goto_ks6

branch goto_ks5
    jump res://sample/demo/demo_05_motion.ks
branch goto_ks6
    jump res://sample/demo/demo_06_bg_effects.ks