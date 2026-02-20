# Local test copies for TrinityX Dashboard branding

Edit these files locally for quick testing. When satisfied, copy changes back to the real sources and deploy with Ansible.

## What each file is (and what’s in ondemand.yml)

| File | Server path | Purpose |
|------|-------------|---------|
| **en.yml** | `/var/www/ood/apps/sys/dashboard/config/locales/en.yml` | Welcome HTML, button labels, all dashboard locale strings. |
| **custom.css** | `/var/www/ood/public/custom.css` | Styles: background, header, buttons, app tiles, footer. |
| **ondemand.yml** | `/etc/ood/config/ondemand.d/ondemand.yml` | OOD config: **nav_bar**, **help_bar**, **pinned_apps**, **custom_css_files**, etc. |

### ondemand.yml keys (pinned_apps、custom_css )

- **nav_bar** – Top **navigation** (left side): which menus appear (e.g. Apps, Files, Jobs, Clusters, Interactive apps, Sessions). List of item names.
- **help_bar** – Top **help/user** (right side): Help, user info, Log out. List of item names (use `log_out` with underscore).
- **pinned_apps** – Which apps show as **pinned tiles** on the dashboard (e.g. `sys/shell`, `sys/bc_*`, `sys/trinity_*`).
- **pinned_apps_group_by** – How pinned apps are grouped (e.g. `category`).
- **custom_css_files** – URLs of **custom CSS** to load (e.g. `["/custom.css"]`).

So “导航、pinned_apps、custom_css 等” = the **navigation menus**, **pinned app list**, **custom CSS list**, and related options in `ondemand.yml`.

### Where do section titles like "Interactive Apps" come from?

They are **not** in **en.yml**. OOD builds them from each app's **manifest** (e.g. `manifest.yml`): the **category** field becomes the section title when `pinned_apps_group_by: category` is set. So "Interactive Apps", "Luna - Provisioning Engine", etc. are rendered by the dashboard view `widgets/pinned_apps/_group.html.erb`. You can only change their **style** in **custom.css** (e.g. color `#6969ff`, underline). To change the **text**, you would edit each app's manifest category on the server.

## How to use

1. Edit **en.yml**, **custom.css**, **ondemand.yml** here.
2. Copy to the server at the paths above (or run your playbook and overwrite with these files for testing).
3. Restart: **Help → Restart Web Server** in the dashboard.
4. When the design is final, apply the same changes to the real sources:
   - **en.yml** → merge into `templates/branding/TrinityX/en.yml.j2` (welcome_html block; keep or remove `{{ trinityx_logo_html }}` / `{{ trinityx_text_html }}` as needed).
   - **custom.css** → copy to `files/branding/TrinityX/custom.css`.
   - **ondemand.yml** → copy to `templates/branding/TrinityX/ondemand.yml.j2` (if no Jinja2 vars).

**Important:** Do **not** copy `en.yml.j2` from the repo to the server as `en.yml` (that leaves unrendered Jinja2 and causes 500). Use the **en.yml** in this folder (already rendered) or run Ansible **template** to generate en.yml from en.yml.j2.
