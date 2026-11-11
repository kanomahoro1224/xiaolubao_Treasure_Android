#!/usr/bin/env python3
"""从 `kano_strings_source.json` 生成 `lib/features/kano/domain/kano_strings.dart`。

`kano_strings_source.json` 是鸿蒙工程四份 `element/string.json` 的合并结果：
    {"<资源名>": {"base": "...", "zh_Hant": "...", "ja_JP": "...", "en_US": "..."}}
缺项时回落 base（鸿蒙侧也是这个行为：资源缺失回落到 base 目录）。

用法（在工程根目录）：
    python tool/gen_kano_strings.py

生成的 dart 文件不要手改；改文案请改上游 string.json 后重新生成本 JSON 再跑一遍。
"""

from __future__ import annotations

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "tool" / "kano_strings_source.json"
TARGET = ROOT / "lib" / "features" / "kano" / "domain" / "kano_strings.dart"

LANGS = ("base", "zh_Hant", "ja_JP", "en_US")
HEADER = '''/// 四语文案表（由鸿蒙 `resources/{base,zh_Hant,ja_JP,en_US}/element/string.json` 生成）。
///
/// 每行按 简中 / 繁中 / 日 / 英 排列，key 与鸿蒙资源名一一对应，
/// 所以两边文案可以逐条对照。**不要手改**：改文案请改上游 string.json 后重新生成。
library;

/// 资源名 → [简中, 繁中, 日, 英]
const kanoStrings = <String, List<String>>{
'''


def dart_string(text: str) -> str:
    """转义成 dart 双引号字符串。"""
    out = []
    for ch in text:
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        elif ch == "$":
            out.append("\\$")
        else:
            out.append(ch)
    return '"' + "".join(out) + '"'


def main() -> None:
    raw = json.loads(SOURCE.read_text(encoding="utf-8"))

    lines = [HEADER]
    for key in sorted(raw):
        row = raw[key]
        values = [row.get(lang) or row.get("base") or "" for lang in LANGS]
        cells = ", ".join(dart_string(v) for v in values)
        lines.append(f"  {dart_string(key)}: [{cells}],\n")
    lines.append("};\n")

    TARGET.write_text("".join(lines), encoding="utf-8", newline="\n")
    print(f"wrote {TARGET.relative_to(ROOT)} — {len(raw)} entries")


if __name__ == "__main__":
    main()
