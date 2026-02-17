# 修复 500：en.yml 中的 Jinja2 未渲染 (Psych::SyntaxError line 32)

服务器上的 `en.yml` 含有未渲染的 Jinja2（`{% set %}`、`{{ }}`），YAML 解析会报错。按下面任选一种方式修复。

## 方法一：在服务器上用 sed 一键修复（推荐）

在 **yixin3-dev-ctrl001** 上执行（先备份再改）：

```bash
FILE=/var/www/ood/apps/sys/dashboard/config/locales/en.yml
sudo cp "$FILE" "$FILE.bak"

# 1) 删除含 Jinja2 的 6 行（约第 31–36 行：注释 + 4 行 {% set %} + 空行）
sudo sed -i '/# Deploy with Ansible template module/,/^$/d' "$FILE"
# 若上面命令删得不对，用下面按行号删（先 head -40 确认行号）：
# sudo sed -i '31,36d' "$FILE"

# 2) 把未渲染的占位符换成实际 HTML
sudo sed -i 's|{{ trinityx_logo_html }}|<div class="trinityx-custom-logo-placeholder"><span class="trinityx-placeholder-label">Logo</span></div>|g' "$FILE"
sudo sed -i 's|{{ trinityx_text_html }}|<div class="trinityx-custom-text-placeholder"><span class="trinityx-placeholder-label">Custom text</span></div>|g' "$FILE"

# 3) 验证 YAML
cd /var/www/ood/apps/sys/dashboard && ruby -r yaml -e "YAML.load_file('config/locales/en.yml')" && echo "OK"
```

若无报错且输出 `OK`，在浏览器里 **Help → Restart Web Server** 再访问 dashboard。

---

## 方法二：用 vim 手动改

1. `sudo vim /var/www/ood/apps/sys/dashboard/config/locales/en.yml`
2. 删掉这 5 行（不要保留在文件里）：
   - `# Deploy with Ansible template module (not copy) so Jinja2 is evaluated.`
   - `{% set _logo_url = trinityx_custom_logo_url | default('') %}`
   - `{% set _welcome_text = trinityx_custom_welcome_text | default('') %}`
   - `{% set trinityx_logo_html = ... %}`
   - `{% set trinityx_text_html = ... %}`
3. 搜索 `{{ trinityx_logo_html }}`，整段换成：  
   `<div class="trinityx-custom-logo-placeholder"><span class="trinityx-placeholder-label">Logo</span></div>`  
   （保留外面的 `<div class="trinityx-custom-logo-wrap">...</div>`，只换中间）
4. 搜索 `{{ trinityx_text_html }}`，整段换成：  
   `<div class="trinityx-custom-text-placeholder"><span class="trinityx-placeholder-label">Custom text</span></div>`
5. 存盘后执行：  
   `cd /var/www/ood/apps/sys/dashboard && ruby -r yaml -e "YAML.load_file('config/locales/en.yml')"`  
   无报错即可。

---

## 以后避免再出现

**不要**把仓库里的 `en.yml.j2` 直接复制成 `en.yml` 使用。  
应用 Ansible 的 **template** 任务从 `en.yml.j2` 生成 `en.yml`，这样 `{% %}` 和 `{{ }}` 会被替换成普通 HTML，不会触发 YAML 错误。
