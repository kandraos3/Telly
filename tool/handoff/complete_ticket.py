"""Usage: python complete.py TICKET NEXT_TICKET "next title" [keep-open-substring ...]

Checks every task of TICKET in Sprint 6, flips Sprint 1-5 items annotated
`→ remediated by `TICKET`` to [x], and advances the dashboard counter.
Tasks whose text contains any keep-open substring stay unchecked.
"""
import re
import sys

ticket, nxt, nxt_title = sys.argv[1], sys.argv[2], sys.argv[3]
keep = sys.argv[4:]
p = 'docs/PROJECT_ROADMAP_AND_SPRINT_PLAN.md'
s = open(p, encoding='utf-8').read()

a = s.index(f'#### `{ticket}`')
b = s.index('\n#### ', a + 10)
b2 = s.find('\n### ', a + 10)
if b2 != -1 and b2 < b:
    b = b2
lines = s[a:b].split('\n')
for i, l in enumerate(lines):
    if '- [ ] ' in l and not any(k in l for k in keep) and 'TO BE DONE BY HUMAN' not in l:
        lines[i] = l.replace('- [ ] ', '- [x] ', 1)
s = s[:a] + '\n'.join(lines) + s[b:]

marker = f' → remediated by `{ticket}`'
flipped = 0
out = []
for l in s.split('\n'):
    if l.endswith(marker) and '- [ ] ' in l:
        l = l.replace('- [ ] ', '- [x] ', 1).replace(marker, f' ✅ remediated in `{ticket}`')
        flipped += 1
    out.append(l)
s = '\n'.join(out)

if nxt == '-':
    open(p, 'w', encoding='utf-8', newline='\n').write(s)
    print(f'{ticket}: flipped {flipped} legacy items (dashboard unchanged)')
    sys.exit(0)
m = re.search(r"- \*\*Current Active Ticket\*\*: .*? — Sprint 6: (\d+) / (\d+) tickets complete", s)
done, total = int(m.group(1)) + 1, int(m.group(2))
s = s[:m.start()] + f"- **Current Active Ticket**: `{nxt}` ({nxt_title}) — Sprint 6: {done} / {total} tickets complete" + s[m.end():]
open(p, 'w', encoding='utf-8', newline='\n').write(s)
print(f'{ticket} checked; flipped {flipped} legacy items; dashboard {done}/{total}')
