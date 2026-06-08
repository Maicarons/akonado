background bg1 none

actor show Kona 正常 at 1
actor change Kona 介绍说话

"Kona" "背景场景会接收过渡效果名称"

actor change Kona 正常
actor change Kona 介绍说话


background bg_effect blinds
"Kona" "这是“blinds”"

background bg1 none
background bg_effect blink
"Kona" "这是“blink”"

background bg1 none
background bg_effect cyberglitch
"Kona" "这是“cyberglitch”"

background bg1 none
background bg_effect erase
"Kona" "这是“erase”"

background bg1 none
background bg_effect fade
"Kona" "这是“fade”"


background bg_effect none
"Kona" "这是“none”"

background bg1 none
background bg_effect vortex
"Kona" "这是“vortex”"

background bg1 none
background bg_effect wave
"Kona" "这是“wave”"

background bg1 none
background bg_effect windmill
"Kona" "这是“windmill”"
background bg1 none

actor change Kona 正常
"Kona" "可以在背景场景中为不同效果制作 enter/exit 动画"

actor change Kona 害羞

"Kona" "背景过渡演示完毕"
# 演员退出
actor exit Kona

background bg_end fade

# 结束语句，是关闭对话框的作用
end

