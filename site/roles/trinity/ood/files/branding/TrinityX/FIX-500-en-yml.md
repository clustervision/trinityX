# Fix 500: unrendered Jinja2 in en.yml (Psych::SyntaxError around line 32)

The server's `en.yml` contains raw Jinja2 (`{% set %}`, `{{ }}`), so YAML parsing fails. Fix using one of the options below.

## Option 1: One-off fix with sed on the server (recommended)

On the node (e.g. **yixin3-dev-ctrl001**), after backing up:

```bash
FILE=/var/www/ood/apps/sys/dashboard/config/locales/en.yml
sudo cp "$FILE" "$FILE.bak"

# 1) Remove the Jinja2 block (comment + 4 {% set %} lines + blank line)
sudo sed -i '/# Deploy with Ansible template module/,/^$/d' "$FILE"
# If that removes too much/little, use line numbers (check with head -40):
# sudo sed -i '31,36d' "$FILE"

# 2) Remove unrendered placeholders (match template: no circle/rectangle by default)
sudo sed -i 's|{{ trinityx_logo_html }}||g' "$FILE"
sudo sed -i 's|{{ trinityx_text_html }}||g' "$FILE"
sudo sed -i 's|<div class="trinityx-custom-logo-wrap"></div>||g' "$FILE"
sudo sed -i 's|<div class="trinityx-custom-text-wrap"></div>||g' "$FILE"

# 3) Validate YAML
cd /var/www/ood/apps/sys/dashboard && ruby -r yaml -e "YAML.load_file('config/locales/en.yml')" && echo "OK"
```

If you see no error and "OK", use **Help → Restart Web Server** in the dashboard and reload.

---

## Option 2: Edit with vim

1. `sudo vim /var/www/ood/apps/sys/dashboard/config/locales/en.yml`
2. Delete these 5 lines (do not keep them):
   - `# Deploy with Ansible template module (not copy) so Jinja2 is evaluated.`
   - `{% set _logo_url = trinityx_custom_logo_url | default('') %}`
   - `{% set _welcome_text = trinityx_custom_welcome_text | default('') %}`
   - `{% set trinityx_logo_html = ... %}`
   - `{% set trinityx_text_html = ... %}`
3. Search for `{{ trinityx_logo_html }}` and remove it (or replace with nothing).
4. Search for `{{ trinityx_text_html }}` and remove it (or replace with nothing).
5. Save, then run:  
   `cd /var/www/ood/apps/sys/dashboard && ruby -r yaml -e "YAML.load_file('config/locales/en.yml')"`  
   and ensure it does not raise.

---

## Avoiding this in the future

Do **not** copy `en.yml.j2` from the repo to `en.yml` on the server.  
Use Ansible **template** to generate `en.yml` from `en.yml.j2` so `{% %}` and `{{ }}` are replaced and YAML stays valid.
