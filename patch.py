with open('js/app.js', 'r', encoding='utf-8') as f:
    t = f.read()

# Fix bottomNav.innerHTML = '
 t = t.replace('header-gym-name')\n  if' , 'header-gym-name');\n  if' )
# Fix all unclosed quotes at line 173
 t = t.replace("bottomNav.innerHTML = '", "bottomNav.innerHTML = `")
 t = t.replace("\n  ';", "\n  `;")

with open('js/app.js', 'w', encoding='utf-8') as f:
    f.write(t)

print('Patched js/app.js')
