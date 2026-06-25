# Konado Script Syntax
为 Konado 引擎自定义 `.ks` 脚本提供 VSCode 语法高亮插件，实现关键字着色、注释识别、语法区分，大幅提升脚本编写开发体验。

# 适用的编辑器
适用所有基于VSCode开发的编辑器，包括但不限于VSCode,Cursor,Trae,Qoder,Codebuddy等

# 插件市场安装(推荐)
1. 打开编辑器,点击扩展图标
2. 搜索 "Konado"
3. 点击安装 Konado Script Syntax 插件
4. 重启编辑器即可生效
5. 有的编辑器的插件市场还没同步，可以下载插件手动安装

# 本地安装
1. 下载插件 konado-script-syntax-*.vsix
2. 点击扩展图标，再点击右上角三个点，点击“从VSIX安装”
3. 重启编辑器即可生效

# 自己打包插件

## 开发依赖
环境必备：
- VSCode
- Node.js

## 构建打包
1. 全局安装 VSCode 插件打包工具 vsce
```bash
npm install -g vsce
```
2. 安装依赖
```bash
npm install
```
3. 打包插件
```bash
vsce package
```

## 许可证    
konado-script-syntax 使用 MIT 许可证，开源且免费使用，具体内容请查看 LICENSE 文件。