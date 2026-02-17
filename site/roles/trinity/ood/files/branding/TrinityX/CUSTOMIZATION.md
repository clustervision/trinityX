# TrinityX Dashboard 自定义说明

**重要：** 必须使用 Ansible 的 `template` 模块部署 `en.yml.j2`（生成 `en.yml`），不能使用 `copy` 直接复制。若用 copy，页面会显示乱码（Jinja2 语法原文）。请确认 playbook 里对应任务为 `ansible.builtin.template`，部署后执行 Help → Restart Web Server。

Dashboard 欢迎区中间有两个可自定义区域（默认显示为深灰色占位）：

- **深灰圆形**：用于放置站点/单位自己的 Logo
- **深灰长框**：用于放置自定义说明文字

## 用户如何自定义

### 方法一：通过 Ansible 变量（推荐）

在 Play 或 `group_vars` 中为对应主机/组设置变量，然后重新运行包含 OOD 品牌的 Playbook：

**自定义 Logo（替换圆形占位）：**

```yaml
trinityx_custom_logo_url: "https://your-site.com/logo.png"
```

或使用部署机器上的相对路径（需确保 Dashboard 能访问），例如 OOD 的 public 目录下的图片：

```yaml
trinityx_custom_logo_url: "/custom/logo.png"
```

**自定义文字（替换深灰长框内容）：**

```yaml
trinityx_custom_welcome_text: "这里是您的自定义说明，例如站点使用须知、公告等。支持多行。"
```

设置后重新执行部署（例如 `ansible-playbook site.yml` 或只跑 OOD 相关 tag），再在 Dashboard 中通过 **Help → Restart Web Server** 重启一次，即可看到效果。

### 方法二：直接改生成的 locale 文件

若不想改 Ansible 变量，可在部署完成后直接编辑：

- 文件路径：`/var/www/ood/apps/sys/dashboard/config/locales/en.yml`
- 在 `en.dashboard.welcome_html` 的 YAML 多行字符串中：
  - 找到 `trinityx-custom-logo-placeholder` 的 `<div>`，改为 `<img src="你的 logo URL" alt="Logo" class="trinityx-custom-logo-img">`
  - 找到 `trinityx-custom-text-placeholder` 的 `<div>`，改为 `<p class="trinityx-custom-text">你的自定义文字</p>`

保存后同样需要 **Help → Restart Web Server** 才会生效。注意下次用 Ansible 重新部署时，若再次渲染 `en.yml.j2`，会覆盖手动修改。

---

**小结：** 推荐用方法一，在 Ansible 中设置 `trinityx_custom_logo_url` 和 `trinityx_custom_welcome_text`，便于版本控制和重复部署。

---

## 出现 500 Internal Server Error 时

若**没有改过 ondemand.yml** 就报 500，多半是 **en.yml（locale）** 或 **custom.css** 引起的。

1. **拿到 500 的具体错误信息**（才能对症修复）：
   - **浏览器里**：开发者工具 → Network → 点开返回 500 的请求（如 `/pun/sys/dashboard`）→ 切到 **Response**，看响应正文（约 182 B 的那段），常有 `SyntaxError`、`Psych::SyntaxError`（YAML）、或 Ruby 异常。
   - **服务器上**（在 **yixin3-dev-ctrl001** 或运行 OOD 的 node 上）：
     - Nginx/Passenger 错误：`sudo tail -100 /var/log/nginx/error.log` 或 `sudo tail -100 /var/log/ood/nginx/error.log`
     - 系统日志：`sudo journalctl -u nginx -n 50 --no-pager` 或 `sudo journalctl -u httpd -n 50 --no-pager`
     - 若可切到对应用户：`~/ondemand/data/sys/dashboard/log/production.log` 或 `development.log`（看最近几行 Ruby 堆栈）
   - 其他可能位置：`/var/log/httpd/error_log`（Apache）、`/var/log/messages` 里与 nginx/httpd 相关的行。
   - 日志里会有 Ruby 异常或堆栈，能看出是加载 locale 失败、YAML 解析错误还是别处出错。

1b. **在 node 上直接检查 en.yml 是否合法**（推荐先做）  
   若你改过 `/var/www/ood/apps/sys/dashboard/config/locales/en.yml`，先确认 YAML 没写坏。在 **yixin3-dev-ctrl001** 上执行：
   ```bash
   cd /var/www/ood/apps/sys/dashboard && ruby -r yaml -e "YAML.load_file('config/locales/en.yml')"
   ```
   - 若**报错**：终端里会打出 `Psych::SyntaxError` 或类似，并带行号/原因，按提示改 en.yml 或恢复备份。
   - 若**无输出**：说明 YAML 语法没问题，500 多半是别处（例如缺少某个 key）；可再查 nginx/httpd 或 Passenger 日志。

2. **先确认是不是 en.yml 导致的**：
   - 备份当前：`sudo cp /var/www/ood/apps/sys/dashboard/config/locales/en.yml /var/www/ood/apps/sys/dashboard/config/locales/en.yml.bak`
   - 从 OOD 包恢复默认：`sudo yum reinstall ondemand` 或从包中取出默认的 `en.yml` 覆盖到该路径，然后重启 Web Server。
   - 若恢复默认后 500 消失，则问题在 **TrinityX 的 en.yml 内容**；再用本仓库的 template 重新生成一次（确保用 **Ansible template**，不要 copy），并确认生成的 YAML 合法。模板里已保留 `%{logo_img_tag}` 占位（隐藏），避免视图缺少该插值时报错。

3. **若在改完 `ondemand.yml` 后出现 500**：
   - 确认 `help_bar` 的登出项为 **`log_out`**（带下划线），不是 `logout`。
   - 可暂时注释或删除 `nav_bar` 与 `help_bar` 整段后再试。

4. **若在改完 locale（en.yml）后出现 500**：
   - 必须用 **Ansible template** 从 `en.yml.j2` 生成 `en.yml`，不要直接复制 `.j2` 到 `en.yml`。
   - 检查生成的 `en.yml` 中 `welcome_html` 的 YAML 是否合法（缩进、引号、冒号）。
