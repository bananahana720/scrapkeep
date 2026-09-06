#!/usr/bin/env bash
cd /home/andrew/Projects/scrapkeep-wt-PS-04 || exit 2
echo "== grep -n 'HF-10-foundation-review' BACKLOG.md (only the new path expected)"
grep -n 'HF-10-foundation-review' BACKLOG.md | cut -c1-140
echo "== grep -c '^### HF-' BACKLOG.md (expect 14)"
grep -c '^### HF-' BACKLOG.md
echo "== grep -c '^### S0-' BACKLOG.md (expect 9)"
grep -c '^### S0-' BACKLOG.md
echo "== BACKLOG section headings (expect none, grep exit 1)"
grep -n '^## Source dispositions\|^## Source inventory' BACKLOG.md
echo "exit=$?"
echo "== SOURCE-DISPOSITIONS section headings (expect both)"
grep -n '^## Source dispositions\|^## Source inventory' docs/project/SOURCE-DISPOSITIONS.md
echo "== old split anchors anywhere (expect none, exit 1)"
grep -n '(#hf-0[3467])\|BACKLOG.md#hf-0[3467])' BACKLOG.md ORCHESTRATOR.md docs/project/README.md docs/project/SOURCE-DISPOSITIONS.md
echo "exit=$?"
echo "== registered non-blocking fields (expect 5)"
grep -c 'Registered non-blocking questions:' BACKLOG.md
echo "== re-verify triggers naming S0 cards"
grep -o 're-verify when S0-0[0-9] lands\|Re-verify when S0-0[0-9] lands' BACKLOG.md | sort | uniq -c
echo "== long-dash scan of edited prose outside the verbatim move (expect none, exit 1)"
grep -n $'\xe2\x80\x94' BACKLOG.md ORCHESTRATOR.md docs/project/README.md | cut -c1-100
echo "exit=$?"
