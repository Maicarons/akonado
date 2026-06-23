# Konado Script Syntax
为 Konado 引擎自定义 `.ks` 脚本提供 VSCode 语法高亮插件，实现关键字着色、注释识别、语法区分，大幅提升脚本编写开发体验。

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

3. 安装
```bash
code --install-extension konado-script-syntax-1.0.0.vsix
```
## 许可证    
konado-script-syntax 使用 MIT 许可证，开源且免费使用，具体内容请查看 LICENSE 文件。