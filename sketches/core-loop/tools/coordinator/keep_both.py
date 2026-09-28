import sys
p = sys.argv[1]
out = []
for line in open(p):
    if line.startswith("<<<<<<< ") or line.startswith("=======") or line.startswith(">>>>>>> "):
        if line.startswith("=======") and line.strip() != "=======":
            out.append(line)
        continue
    out.append(line)
open(p, "w").write("".join(out))
