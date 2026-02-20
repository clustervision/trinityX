# TrinityX Dashboard customization

**Important:** Deploy `en.yml.j2` with Ansible **template** (to generate `en.yml`). Do not use **copy** or the page may show raw Jinja2 and break. Ensure the playbook task uses `ansible.builtin.template`; after deploy run Help → Restart Web Server.

## Circular and rectangular areas (hidden by default)

The dashboard welcome area has two **optional** custom blocks that are **hidden by default** (no placeholder boxes):

- **Circle:** Shown only when a custom logo URL is set; used for the customer logo.
- **Rectangle:** Shown only when custom welcome text is set; used for notices or custom text.

They appear only when the customer sets the variables below.

---

## How to add custom logo and text

### Method 1: Ansible variables (recommended)

Set these in play or `group_vars` for the host/group, then re-run the playbook that applies OOD branding:

**Custom logo:**

```yaml
trinityx_custom_logo_url: "https://your-site.com/logo.png"
```

Or a path under OOD public (must be reachable by the dashboard), e.g.:

```yaml
trinityx_custom_logo_url: "/custom/logo.png"
```

**Custom text:**

```yaml
trinityx_custom_welcome_text: "Your custom message, notices, etc. Multi-line supported."
```

Re-run the playbook (e.g. `ansible-playbook site.yml` or the OOD tag), then **Help → Restart Web Server** in the dashboard.

### Method 2: Edit the generated locale file

Edit the file after deploy:

- Path: `/var/www/ood/apps/sys/dashboard/config/locales/en.yml`
- In the `en.dashboard.welcome_html` block:
  - To show a logo: between "Follow us on GitHub" and "Read the Docs" insert:  
    `<div class="trinityx-custom-logo-wrap"><img src="YOUR_LOGO_URL" alt="Logo" class="trinityx-custom-logo-img"></div>`
  - To show custom text: below the buttons and above the divider insert:  
    `<div class="trinityx-custom-text-wrap"><p class="trinityx-custom-text">Your custom text</p></div>`

Then **Help → Restart Web Server**. Re-running the playbook with template will overwrite manual edits.

---

**Summary:** Prefer Method 1 with `trinityx_custom_logo_url` and `trinityx_custom_welcome_text` for version control and repeat deploys.

---

## Code notes (en.yml.j2 and custom.css)

### 1. Why circle and rectangle are hidden by default

At the top of **en.yml.j2**, Jinja2 sets:

- **`trinityx_logo_html`**: Empty string when `trinityx_custom_logo_url` is not set (no HTML, no circle). When set, outputs the logo wrap and `<img>`.
- **`trinityx_text_html`**: Empty string when `trinityx_custom_welcome_text` is not set (no rectangle). When set, outputs the text wrap and `<p>...</p>`.

`welcome_html` only contains `{{ trinityx_logo_html }}` and `{{ trinityx_text_html }}` with no fixed wrapper divs, so when they are empty nothing is rendered.

### 2. Button styles

- Left two (Our website, Follow us on GitHub): `trinityx-btn-light` — white background, purple border/text.
- Right two (Read the Docs, Support Portal): `trinityx-btn-primary` — solid purple, white text.

### 3. Section titles and footer

- Pinned app category titles: `#pinned_apps h2` etc. use `border-bottom: 3px solid #5a4fcf` in **custom.css**.
- Footer: `footer.d-flex` uses a purple-to-orange gradient in **custom.css**.

---

## When you see 500 Internal Server Error

If 500 appears **without** changing ondemand.yml, it is often **en.yml** (locale) or **custom.css**.

1. **Get the actual error:**
   - Browser: DevTools → Network → select the 500 request (e.g. `/pun/sys/dashboard`) → Response tab.
   - Server: `sudo tail -100 /var/log/nginx/error.log`, `sudo journalctl -u nginx -n 50 --no-pager`, or `~/ondemand/data/sys/dashboard/log/production.log` (if applicable).

1b. **Validate en.yml on the node:**

   ```bash
   cd /var/www/ood/apps/sys/dashboard && ruby -r yaml -e "YAML.load_file('config/locales/en.yml')"
   ```
   - If it raises, fix the reported line in en.yml or restore from backup.
   - If it prints nothing, YAML is valid; check nginx/Passenger logs.

2. **If en.yml might be the cause:** Backup, restore default en.yml (e.g. from package), restart; if 500 goes away, fix or re-deploy the TrinityX en.yml via Ansible template.

3. **If 500 started after editing ondemand.yml:** Use `log_out` (with underscore) in `help_bar`, not `logout`. You can temporarily remove `nav_bar` and `help_bar` to test.

4. **If 500 started after editing locale:** Always generate en.yml with Ansible **template** from en.yml.j2, not copy. Check that the generated `welcome_html` block is valid YAML.
