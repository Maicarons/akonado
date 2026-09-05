#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Godot插件资源引用检查工具
功能：检查插件目录内的场景/脚本/资源文件，确保所有资源引用都在插件目录内
使用方式：python3 .github/scripts/check_plugin_resource_boundaries.py <插件res路径> <插件本地目录>
示例：python3 .github/scripts/check_plugin_resource_boundaries.py "res://addons/konado/" "./addons/konado/"
"""

import os
import re
import sys
from typing import List, Tuple, Dict

# 定义需要检查的文件类型
CHECK_FILE_TYPES = (".tscn", ".gd", ".res")

# 正则表达式匹配规则
# 匹配tscn文件中的ext_resource path：[ext_resource ... path="res://xxx" ...]
REGEX_TSCN_PATH = re.compile(r'path=["\']res://([^"\']+)["\']', re.IGNORECASE)
# 匹配gd脚本中的load/preload：load("res://xxx") 或 preload('res://xxx')
REGEX_GD_LOAD = re.compile(r'(load|preload)\(["\']res://([^"\']+)["\']\)', re.IGNORECASE)


def normalize_res_path(res_path: str) -> str:
    """
    规范化res路径：确保以/结尾，且去除多余的斜杠
    """
    res_path = res_path.strip().replace("\\", "/")
    if not res_path.startswith("res://"):
        raise ValueError(f"res路径必须以res://开头: {res_path}")
    if not res_path.endswith("/"):
        res_path += "/"
    return res_path


def check_tscn_file(file_path: str, plugin_res_prefix: str) -> List[Dict[str, str]]:
    """
    检查tscn文件中的资源引用（带行号）
    :param file_path: 本地文件路径
    :param plugin_res_prefix: 插件的res路径前缀（如res://addons/konado/）
    :return: 违规引用列表 [{"file": 文件路径, "line": 行号, "path": 违规路径, "content": 行内容}]
    """
    violations = []
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            for line_num, line_content in enumerate(f, 1):
                # 匹配当前行的path属性
                matches = REGEX_TSCN_PATH.findall(line_content)
                for match in matches:
                    full_res_path = f"res://{match}"
                    # 检查是否在插件目录内
                    if not full_res_path.startswith(plugin_res_prefix):
                        violations.append({
                            "file": file_path,
                            "line": str(line_num),
                            "path": full_res_path,
                            "content": line_content.strip()
                        })
    except Exception as e:
        violations.append({
            "file": file_path,
            "line": "0",
            "path": f"文件读取失败: {str(e)}",
            "content": ""
        })
    return violations


def check_gd_file(file_path: str, plugin_res_prefix: str) -> List[Dict[str, str]]:
    """
    检查gd脚本中的load/preload引用（带行号）
    :param file_path: 本地文件路径
    :param plugin_res_prefix: 插件的res路径前缀
    :return: 违规引用列表 [{"file": 文件路径, "line": 行号, "path": 违规路径, "content": 行内容}]
    """
    violations = []
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            for line_num, line_content in enumerate(f, 1):
                # 匹配当前行的load/preload路径
                matches = REGEX_GD_LOAD.findall(line_content)
                for _, match in matches:
                    full_res_path = f"res://{match}"
                    # 检查是否在插件目录内
                    if not full_res_path.startswith(plugin_res_prefix):
                        violations.append({
                            "file": file_path,
                            "line": str(line_num),
                            "path": full_res_path,
                            "content": line_content.strip()
                        })
    except Exception as e:
        violations.append({
            "file": file_path,
            "line": "0",
            "path": f"文件读取失败: {str(e)}",
            "content": ""
        })
    return violations


def check_res_file(file_path: str, plugin_res_prefix: str) -> List[Dict[str, str]]:
    """
    检查res文件（带行号，二进制文件单独标记）
    """
    violations = []
    try:
        # 尝试以文本方式打开（部分res文件是文本格式）
        with open(file_path, "r", encoding="utf-8") as f:
            for line_num, line_content in enumerate(f, 1):
                # 复用tscn的正则匹配（文本res文件格式类似）
                matches = REGEX_TSCN_PATH.findall(line_content)
                for match in matches:
                    full_res_path = f"res://{match}"
                    if not full_res_path.startswith(plugin_res_prefix):
                        violations.append({
                            "file": file_path,
                            "line": str(line_num),
                            "path": full_res_path,
                            "content": line_content.strip()
                        })
    except UnicodeDecodeError:
        # 二进制res文件无法解析，记录提示
        violations.append({
            "file": file_path,
            "line": "0",
            "path": "二进制.res文件无法解析，需手动检查",
            "content": ""
        })
    except Exception as e:
        violations.append({
            "file": file_path,
            "line": "0",
            "path": f"文件读取失败: {str(e)}",
            "content": ""
        })
    return violations


def scan_directory(root_dir: str, plugin_res_prefix: str) -> Tuple[List[Dict[str, str]], int]:
    """
    遍历目录检查所有目标文件
    :param root_dir: 插件本地根目录
    :param plugin_res_prefix: 插件的res路径前缀
    :return: (所有违规引用列表, 检查的文件总数)
    """
    all_violations = []
    checked_files_count = 0
    
    for root, _, files in os.walk(root_dir):
        for file in files:
            # 筛选需要检查的文件类型
            if not file.endswith(CHECK_FILE_TYPES):
                continue
            
            checked_files_count += 1
            file_path = os.path.join(root, file)
            
            # 根据文件类型调用不同检查函数
            if file.endswith(".tscn"):
                violations = check_tscn_file(file_path, plugin_res_prefix)
            elif file.endswith(".gd"):
                violations = check_gd_file(file_path, plugin_res_prefix)
            elif file.endswith(".res"):
                violations = check_res_file(file_path, plugin_res_prefix)
            else:
                violations = []
            
            all_violations.extend(violations)
    
    return all_violations, checked_files_count


def main():
    # 检查命令行参数
    if len(sys.argv) != 3:
        print("使用方式错误！正确用法：")
        print(f"python3 {sys.argv[0]} <插件res路径> <插件本地目录>")
        print("示例：")
        print(f"python3 {sys.argv[0]} \"res://addons/konado/\" \"./addons/konado/\"")
        sys.exit(1)
    
    # 解析参数
    plugin_res_path = sys.argv[1]
    plugin_local_dir = sys.argv[2]
    
    # 验证本地目录是否存在
    if not os.path.isdir(plugin_local_dir):
        print(f"错误：本地目录不存在 - {plugin_local_dir}")
        sys.exit(1)
    
    # 规范化res路径
    try:
        plugin_res_prefix = normalize_res_path(plugin_res_path)
    except ValueError as e:
        print(f"错误：{e}")
        sys.exit(1)
    
    # 打印检查配置（适配CI日志）
    print(f"[INFO] 开始检查Godot插件资源引用")
    print(f"[INFO] 插件Res路径前缀: {plugin_res_prefix}")
    print(f"[INFO] 插件本地目录: {os.path.abspath(plugin_local_dir)}")
    print(f"[INFO] 检查文件类型: {', '.join(CHECK_FILE_TYPES)}")
    print("-" * 60)
    
    # 扫描并检查所有文件
    violations, checked_files_count = scan_directory(plugin_local_dir, plugin_res_prefix)
    violation_files = set([v["file"] for v in violations])
    violation_count = len(violations)
    
    # 输出检查统计
    print(f"[INFO] 检查完成 - 总文件数: {checked_files_count}, 违规文件数: {len(violation_files)}, 违规引用数: {violation_count}")
    print("-" * 60)
    
    # 输出违规详情（适配GitHub Action错误格式）
    if violations:
        print("[ERROR] 发现违规外部资源引用：")
        for idx, violation in enumerate(violations, 1):
            # GitHub Action错误注解格式：::error file={文件路径},line={行号}::{错误信息}
            gh_action_error = f"::error file={violation['file']},line={violation['line']}::违规引用外部资源: {violation['path']}"
            print(gh_action_error)
            # 补充详细信息（方便日志查看）
            print(f"[{idx}] 文件: {violation['file']} (行: {violation['line']})")
            print(f"       引用路径: {violation['path']}")
            if violation["content"]:
                print(f"       行内容: {violation['content']}")
            print()
        
        print("[FAILURE] 检查未通过：存在外部资源引用")
        sys.exit(1)
    else:
        print("[SUCCESS] 检查通过：所有资源引用均在插件目录内")
        sys.exit(0)


if __name__ == "__main__":
    main()
