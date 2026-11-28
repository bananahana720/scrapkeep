"""Move every hand-written "am I the script being run" test under scripts/ onto isMain() of scripts/lib/cli.mjs.

Run from the root of a checkout:  python3 -I <this file> [--check]
Rewrites files in place and prints one line per file changed. Safe to rerun: a second run changes nothing.
With --check it writes nothing and exits 1 when a file would change.
"""
import os, re, sys

CHECK = "--check" in sys.argv
ROOT = "scripts"
HELPER = "scripts/lib/cli.mjs"
SKIP = {HELPER, "scripts/lib/cli.test.mjs"}
ARGV = r"process\.argv\[1\]"
URL = r"fileURLToPath\(\s*import\.meta\.url\s*\)"
COND = re.compile(
    r"(?:" + ARGV + r"\s*&&\s*)?(?:"
    r"realpathSync\(\s*" + ARGV + r"\s*\)\s*===\s*realpathSync\(\s*" + URL + r"\s*\)"
    r"|realpathSync\(\s*" + URL + r"\s*\)\s*===\s*realpathSync\(\s*" + ARGV + r"\s*\)"
    r"|realpathSync\(\s*" + ARGV + r"\s*\)\s*===\s*" + URL +
    r"|path\.resolve\(\s*" + ARGV + r"\s*\)\s*===\s*" + URL +
    r"|" + URL + r"\s*===\s*path\.resolve\(\s*" + ARGV + r"\s*\)"
    r")"
)
LOCAL = re.compile(r"\nfunction isMain\(\) \{\n(?:  .*\n)+?\}\n")
IMPORT = re.compile(r'^import\s[^;]*?from\s+"[^"]+";$|^import\s+"[^"]+";$', re.M)
CLI_IMPORT = re.compile(r'^import \{([^}]*)\} from "([^"]*lib/cli\.mjs|\./cli\.mjs)";$', re.M)


def drop_unused(text, name):
    if len(re.findall(r"(?<![\w.$])" + re.escape(name) + r"(?![\w$])", text)) != 1:
        return text
    def fix(m):
        names = [n.strip() for n in m.group(1).split(",") if n.strip()]
        if name not in names:
            return m.group(0)
        names.remove(name)
        return "import { %s } from %s;\n" % (", ".join(names), m.group(2)) if names else ""
    return re.sub(r"^import \{([^}]*)\} from (\"[^\"]+\");\n", fix, text, flags=re.M)


def convert(rel, text):
    new = COND.sub("isMain(import.meta.url)", text)
    local = LOCAL.search(new)
    if local and "process.argv[1]" in local.group(0):
        new = new.replace(local.group(0), "\n")
        new = re.sub(r"(?<![\w.$])isMain\(\)", "isMain(import.meta.url)", new)
    if new == text:
        return text
    spec = os.path.relpath(HELPER, os.path.dirname(rel)).replace(os.sep, "/")
    if not spec.startswith("."):
        spec = "./" + spec
    have = CLI_IMPORT.search(new)
    if have:
        names = [n.strip() for n in have.group(1).split(",") if n.strip()]
        if "isMain" not in names:
            names = sorted(names + ["isMain"])
            new = new[: have.start()] + 'import { %s } from "%s";' % (", ".join(names), have.group(2)) + new[have.end():]
    else:
        last = list(IMPORT.finditer(new))[-1]
        new = new[: last.end()] + '\nimport { isMain } from "%s";' % spec + new[last.end():]
    for name in ("realpathSync", "fileURLToPath"):
        new = drop_unused(new, name)
    if len(re.findall(r"(?<![\w.$])path(?![\w$])", new)) == 1:
        new = new.replace('import path from "node:path";\n', "")
    return new


changed = 0
for folder, _, files in sorted(os.walk(ROOT)):
    for name in sorted(files):
        rel = os.path.join(folder, name).replace(os.sep, "/")
        if not name.endswith((".mjs", ".js")) or rel in SKIP:
            continue
        text = open(rel).read()
        new = convert(rel, text)
        if new != text:
            changed += 1
            print(rel)
            if not CHECK:
                open(rel, "w").write(new)
print("%d file(s) %s" % (changed, "would change" if CHECK else "changed"))
sys.exit(1 if CHECK and changed else 0)
