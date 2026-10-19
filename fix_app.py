import re

with open('js/app.js', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Clean up lines around line 170-195
out = []
skip = False
for i, line in enumerate(lines):
    if 'bottomNav.innerHTML = '' in line:
        out.append('  bottomNav.innerHTML = ;
')
    else:
        out.append(line)

with open('js/app.js', 'w', encoding='utf-8') as f:
    f.writelines(out)

print('fix_app.py complete')
