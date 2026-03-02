## TrinityX OOD app icons

This file documents where to put the TrinityX OOD app icons, and which file names to use in this repo.

- **Icon files go here (for deploy by Ansible):**
  - `files/branding/TrinityX/app-icons/`
- **These are the *web-ready* icons** (SVG/PNG). If you have source files (e.g. .ai, .fig), keep them outside this role.
- The Ansible role can later copy these icons to each app directory under `/var/www/ood/apps/sys/<app_name>/icon.svg`.

### Recommended file names

Based on your design file names (e.g. "OOD Icons_CodeServer"), use the following repo file names under `app-icons/`:

| Design name (Windows)      | Repo file name (put under `app-icons/`) |
|----------------------------|------------------------------------------|
| `OOD Icons_AlertManager`   | `alertmanager.svg`                       |
| `OOD Icons_AlertX`         | `alertx.svg`                             |
| `OOD Icons_BMC Setup`      | `bmc-setup.svg`                          |
| `OOD Icons_Cluster`        | `cluster.svg`                            |
| `OOD Icons_CodeServer`     | `code-server.svg`                        |
| `OOD Icons_Control`        | `control.svg`                            |
| `OOD Icons_Desktop`        | `desktop.svg`                            |
| `OOD Icons_DNS`            | `dns.svg`                                |
| `OOD Icons_Groups`         | `groups.svg`                             |
| `OOD Icons_Infiniband`     | `infiniband.svg`                         |
| `OOD Icons_Luna`           | `luna.svg`                               |
| `OOD Icons_Monitoring`     | `monitoring.svg`                         |
| `OOD Icons_Network`        | `network.svg`                            |
| `OOD Icons_Nodes`          | `nodes.svg`                              |
| `OOD Icons_OS ImagesTags`  | `os-images-tags.svg`                     |
| `OOD Icons_OSImages`       | `os-images.svg`                          |
| `OOD Icons_OtherDevices`   | `other-devices.svg`                      |
| `OOD Icons_PSSWD`          | `psswd.svg`                              |
| `OOD Icons_Rack`           | `rack.svg`                               |
| `OOD Icons_Secrets`        | `secrets.svg`                            |
| `OOD Icons_Service`        | `service.svg`                            |
| `OOD Icons_Shell`          | `shell.svg`                              |
| `OOD Icons_Switch`         | `switch.svg`                             |
| `OOD Icons_Users`          | `users.svg`                              |

You can use `.svg` or `.png` depending on your export format; keep the base names the same.

### How these will be used (high level)

- This role does **not yet** ship app-specific icon tasks.
- A future Ansible task can loop over a mapping (e.g. app name → repo file name) and:
  - copy `app-icons/<file>` to `/var/www/ood/apps/sys/<app_name>/icon.svg`
  - ensure each app’s `manifest.yml` has `icon: /icon.svg`

Until then, this file serves as the single source of truth for icon file names in the repo.

