#!/usr/bin/env python3
"""对拉下来的 BambuStudio 源码做最小补丁。

为什么需要这一步
----------------
`core/sources.txt` 是一份固定的源文件快照（185 个文件），而 CI 每次拉
master。上游 master 会不断在**已编译的文件里**加进对新库的调用，链接时就
变成 Undefined symbols。

当前只有两处必须掐掉，因为它们把我们没编的库拖进来：

1. `normalize_utf8_nfc()` —— 用 boost.locale 做 NFC 规范化。
   boost.locale 需要 ICU 或 iconv，我们没编。切片不依赖 NFC 规范化
   （只影响文件名显示），直接返回原串。

2. `set_log_path_and_level()` —— 构造 `LogSinkBackend`，后者用 libcurl +
   OpenSSL 上传加密日志。iOS 端不需要往 Bambu 服务器传日志，
   而且我们在入口就把 boost.log 关掉了（见 Libslic3rBackend.cpp）。

改法用「花括号配对」定位函数体，不依赖具体文本内容，上游格式微调也不会失效。
函数不存在时静默跳过（说明上游删了它，那就不需要补丁）。
"""

import sys
from pathlib import Path


def find_function_span(text: str, signature: str):
    """返回 (body_start, body_end)，即函数体 `{` 之后到匹配 `}` 的位置。"""
    idx = text.find(signature)
    if idx < 0:
        return None
    brace = text.find("{", idx)
    if brace < 0:
        return None
    depth = 0
    i = brace
    while i < len(text):
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return brace + 1, i
        i += 1
    return None


def replace_body(text: str, signature: str, new_body: str):
    span = find_function_span(text, signature)
    if span is None:
        return text, False
    start, end = span
    return text[:start] + new_body + text[end:], True


def main() -> int:
    if len(sys.argv) < 2:
        print("用法: patch_upstream.py <BambuStudio 源码根>", file=sys.stderr)
        return 2
    root = Path(sys.argv[1])
    utils = root / "src" / "libslic3r" / "utils.cpp"
    if not utils.is_file():
        print(f"[patch] 找不到 {utils}", file=sys.stderr)
        return 1

    text = utils.read_text(encoding="utf-8", errors="replace")
    original = text

    text, did_nfc = replace_body(
        text,
        "std::string normalize_utf8_nfc(const char *src)",
        """
    // [iOS port] boost.locale 未编入（需要 ICU / iconv）。
    // NFC 规范化只影响文件名显示，切片结果不受影响，原样返回。
    return src != nullptr ? std::string(src) : std::string();
""",
    )

    text, did_log = replace_body(
        text,
        "void set_log_path_and_level(const std::string& file, unsigned int level, "
        "const LogEncOptions& enc_options)",
        """
    // [iOS port] LogSinkBackend 依赖 libcurl + OpenSSL 上传加密日志，未移植。
    // App 入口已关闭 boost.log，这里保持空实现即可。
    (void)file;
    (void)level;
    (void)enc_options;
    return;
""",
    )

    if text != original:
        utils.write_text(text, encoding="utf-8")

    print(f"[patch] normalize_utf8_nfc: {'已改' if did_nfc else '未找到（跳过）'}")
    print(f"[patch] set_log_path_and_level: {'已改' if did_log else '未找到（跳过）'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
