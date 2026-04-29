# ipass LuCI Connectivity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `luci-app-ipass`, a lightweight Chinese LuCI plugin that checks router-side DNS and HTTP/HTTPS reachability for configurable website cards on page load and manual refresh.

**Architecture:** Use a traditional LuCI package with Lua controller, CBI configuration page, HTML template status page, UCI config, and a small POSIX shell checker. The package has no daemon and no scheduler; checks run only when the LuCI page calls the JSON endpoint. GitHub Actions builds the package with the OpenWrt 24.10 `aarch64_generic` SDK on `main`.

**Tech Stack:** OpenWrt 24.10 SDK, LuCI Lua, UCI, POSIX shell, `curl`, BusyBox-compatible tools, GitHub Actions.

---

## File Map

- Create `luci-app-ipass/Makefile`: OpenWrt/LuCI package metadata, dependencies, and `LUCI_PKGARCH:=all`.
- Create `luci-app-ipass/luasrc/controller/ipass.lua`: LuCI menu entries and JSON check endpoint.
- Create `luci-app-ipass/luasrc/model/cbi/ipass/sites.lua`: CBI page for site add/edit/delete/enable/disable.
- Create `luci-app-ipass/luasrc/view/ipass/status.htm`: Chinese status page with card UI and page-local JavaScript.
- Create `luci-app-ipass/root/etc/config/ipass`: default UCI config with 8 site cards.
- Create `luci-app-ipass/root/etc/uci-defaults/90_luci-ipass`: first-install default config guard.
- Create `luci-app-ipass/root/usr/share/ipass/check.sh`: DNS plus HTTP/HTTPS checker emitting JSON.
- Create `luci-app-ipass/root/usr/share/ipass/defaults.json`: machine-readable copy of default site definitions.
- Create `tests/check_sh_tests.sh`: local shell tests for `check.sh` behavior.
- Create `scripts/static-check.sh`: repository package structure and syntax checks.
- Create `scripts/package-run.sh`: wraps `.ipk` artifacts into iStore-compatible `.run` installers.
- Create `.github/workflows/build.yml`: main-only OpenWrt 24.10 SDK package build.
- Modify `README.md`: usage, build, install, and target platform notes.

## Task 1: Package Skeleton and Defaults

**Files:**
- Create: `luci-app-ipass/Makefile`
- Create: `luci-app-ipass/root/etc/config/ipass`
- Create: `luci-app-ipass/root/etc/uci-defaults/90_luci-ipass`
- Create: `luci-app-ipass/root/usr/share/ipass/defaults.json`
- Create: `scripts/static-check.sh`

- [ ] **Step 1: Write the static structure check**

Create `scripts/static-check.sh`:

```sh
#!/bin/sh
set -eu

required_files='
luci-app-ipass/Makefile
luci-app-ipass/root/etc/config/ipass
luci-app-ipass/root/etc/uci-defaults/90_luci-ipass
luci-app-ipass/root/usr/share/ipass/defaults.json
luci-app-ipass/root/usr/share/ipass/check.sh
luci-app-ipass/luasrc/controller/ipass.lua
luci-app-ipass/luasrc/model/cbi/ipass/sites.lua
luci-app-ipass/luasrc/view/ipass/status.htm
'

for file in $required_files; do
  if [ ! -f "$file" ]; then
    echo "missing required file: $file" >&2
    exit 1
  fi
done

grep -q 'LUCI_TITLE:=LuCI support for iPass Connectivity Check' luci-app-ipass/Makefile
grep -q 'LUCI_PKGARCH:=all' luci-app-ipass/Makefile
grep -q 'LUCI_DEPENDS:=+curl +luci-compat +libuci-lua +luci-lib-jsonc' luci-app-ipass/Makefile
grep -q "config site 'baidu'" luci-app-ipass/root/etc/config/ipass
grep -q "config site 'google_204'" luci-app-ipass/root/etc/config/ipass

sh -n luci-app-ipass/root/etc/uci-defaults/90_luci-ipass
if [ -f luci-app-ipass/root/usr/share/ipass/check.sh ]; then
  sh -n luci-app-ipass/root/usr/share/ipass/check.sh
fi

echo "static check passed"
```

- [ ] **Step 2: Run the static check to verify it fails**

Run:

```bash
chmod +x scripts/static-check.sh
./scripts/static-check.sh
```

Expected: FAIL with `missing required file: luci-app-ipass/Makefile`.

- [ ] **Step 3: Create the package Makefile**

Create `luci-app-ipass/Makefile`:

```make
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-ipass
PKG_VERSION:=0.1.0
PKG_RELEASE:=1

LUCI_TITLE:=LuCI support for iPass Connectivity Check
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+curl +luci-compat +libuci-lua +luci-lib-jsonc

define Package/$(PKG_NAME)/conffiles
/etc/config/ipass
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
```

- [ ] **Step 4: Create default UCI config**

Create `luci-app-ipass/root/etc/config/ipass`:

```text
config site 'baidu'
	option name '百度'
	option url 'https://www.baidu.com/'
	option category '国内'
	option enabled '1'
	option timeout '5'

config site 'tencent'
	option name '腾讯'
	option url 'https://www.qq.com/'
	option category '国内'
	option enabled '1'
	option timeout '5'

config site 'aliyun'
	option name '阿里云'
	option url 'https://www.aliyun.com/'
	option category '国内'
	option enabled '1'
	option timeout '5'

config site 'bilibili'
	option name '哔哩哔哩'
	option url 'https://www.bilibili.com/'
	option category '国内'
	option enabled '1'
	option timeout '5'

config site 'google_204'
	option name 'Google 204'
	option url 'https://www.google.com/generate_204'
	option category '国际'
	option enabled '1'
	option timeout '5'

config site 'github'
	option name 'GitHub'
	option url 'https://github.com/'
	option category '国际'
	option enabled '1'
	option timeout '5'

config site 'cloudflare'
	option name 'Cloudflare'
	option url 'https://www.cloudflare.com/'
	option category '国际'
	option enabled '1'
	option timeout '5'

config site 'wikipedia'
	option name 'Wikipedia'
	option url 'https://www.wikipedia.org/'
	option category '国际'
	option enabled '1'
	option timeout '5'
```

- [ ] **Step 5: Create the UCI defaults guard**

Create `luci-app-ipass/root/etc/uci-defaults/90_luci-ipass`:

```sh
#!/bin/sh
set -eu

if [ ! -s /etc/config/ipass ]; then
  cp /rom/etc/config/ipass /etc/config/ipass 2>/dev/null || true
fi

uci -q show ipass | grep -q '=site' || {
  cat > /etc/config/ipass <<'EOF'
config site 'baidu'
	option name '百度'
	option url 'https://www.baidu.com/'
	option category '国内'
	option enabled '1'
	option timeout '5'

config site 'tencent'
	option name '腾讯'
	option url 'https://www.qq.com/'
	option category '国内'
	option enabled '1'
	option timeout '5'

config site 'aliyun'
	option name '阿里云'
	option url 'https://www.aliyun.com/'
	option category '国内'
	option enabled '1'
	option timeout '5'

config site 'bilibili'
	option name '哔哩哔哩'
	option url 'https://www.bilibili.com/'
	option category '国内'
	option enabled '1'
	option timeout '5'

config site 'google_204'
	option name 'Google 204'
	option url 'https://www.google.com/generate_204'
	option category '国际'
	option enabled '1'
	option timeout '5'

config site 'github'
	option name 'GitHub'
	option url 'https://github.com/'
	option category '国际'
	option enabled '1'
	option timeout '5'

config site 'cloudflare'
	option name 'Cloudflare'
	option url 'https://www.cloudflare.com/'
	option category '国际'
	option enabled '1'
	option timeout '5'

config site 'wikipedia'
	option name 'Wikipedia'
	option url 'https://www.wikipedia.org/'
	option category '国际'
	option enabled '1'
	option timeout '5'
EOF
}

exit 0
```

- [ ] **Step 6: Create defaults JSON**

Create `luci-app-ipass/root/usr/share/ipass/defaults.json`:

```json
[
  {"id":"baidu","name":"百度","url":"https://www.baidu.com/","category":"国内","timeout":5},
  {"id":"tencent","name":"腾讯","url":"https://www.qq.com/","category":"国内","timeout":5},
  {"id":"aliyun","name":"阿里云","url":"https://www.aliyun.com/","category":"国内","timeout":5},
  {"id":"bilibili","name":"哔哩哔哩","url":"https://www.bilibili.com/","category":"国内","timeout":5},
  {"id":"google_204","name":"Google 204","url":"https://www.google.com/generate_204","category":"国际","timeout":5},
  {"id":"github","name":"GitHub","url":"https://github.com/","category":"国际","timeout":5},
  {"id":"cloudflare","name":"Cloudflare","url":"https://www.cloudflare.com/","category":"国际","timeout":5},
  {"id":"wikipedia","name":"Wikipedia","url":"https://www.wikipedia.org/","category":"国际","timeout":5}
]
```

- [ ] **Step 7: Run the static check**

Run:

```bash
./scripts/static-check.sh
```

Expected: FAIL until later tasks add `check.sh`, controller, CBI model, and view files.

- [ ] **Step 8: Commit**

Run:

```bash
git add luci-app-ipass/Makefile luci-app-ipass/root/etc/config/ipass luci-app-ipass/root/etc/uci-defaults/90_luci-ipass luci-app-ipass/root/usr/share/ipass/defaults.json scripts/static-check.sh
git commit -m "feat: add ipass package skeleton"
```

## Task 2: DNS and HTTP Checker

**Files:**
- Create: `luci-app-ipass/root/usr/share/ipass/check.sh`
- Create: `tests/check_sh_tests.sh`

- [ ] **Step 1: Write checker tests**

Create `tests/check_sh_tests.sh`:

```sh
#!/bin/sh
set -eu

SCRIPT="${SCRIPT:-./luci-app-ipass/root/usr/share/ipass/check.sh}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  haystack="$1"
  needle="$2"
  printf '%s' "$haystack" | grep -Fq "$needle" || fail "expected output to contain: $needle"
}

invalid_output="$(CHECK_DNS_CMD=true CHECK_CURL_CMD=true "$SCRIPT" 'Bad URL' 'not-a-url' '测试' 1 2)"
assert_contains "$invalid_output" '"ok":false'
assert_contains "$invalid_output" '"error_type":"invalid_url"'

dns_output="$(CHECK_DNS_CMD=false CHECK_CURL_CMD=true "$SCRIPT" 'DNS Fail' 'https://dns-fail.example/' '测试' 1 2)"
assert_contains "$dns_output" '"dns_ok":false'
assert_contains "$dns_output" '"http_ok":false'
assert_contains "$dns_output" '"error_type":"dns_failure"'

http_output="$(CHECK_DNS_CMD=true CHECK_CURL_CMD=false "$SCRIPT" 'HTTP Fail' 'https://http-fail.example/' '测试' 1 2)"
assert_contains "$http_output" '"dns_ok":true'
assert_contains "$http_output" '"http_ok":false'
assert_contains "$http_output" '"error_type":"http_failure"'

success_output="$(CHECK_DNS_CMD=true CHECK_CURL_CMD='printf 204:0.123' "$SCRIPT" 'Google 204' 'https://www.google.com/generate_204' '国际' 1 2)"
assert_contains "$success_output" '"ok":true'
assert_contains "$success_output" '"dns_ok":true'
assert_contains "$success_output" '"http_ok":true'
assert_contains "$success_output" '"http_code":204'
assert_contains "$success_output" '"time_total":0.123'

echo "check.sh tests passed"
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
chmod +x tests/check_sh_tests.sh
./tests/check_sh_tests.sh
```

Expected: FAIL with `./luci-app-ipass/root/usr/share/ipass/check.sh: not found`.

- [ ] **Step 3: Implement `check.sh`**

Create `luci-app-ipass/root/usr/share/ipass/check.sh`:

```sh
#!/bin/sh
set -eu

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

emit_json() {
  name="$1"
  url="$2"
  category="$3"
  enabled="$4"
  timeout="$5"
  host="$6"
  dns_ok="$7"
  http_ok="$8"
  ok="$9"
  http_code="${10}"
  time_total="${11}"
  error_type="${12}"
  error_message="${13}"

  now="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)"
  printf '{'
  printf '"name":"%s",' "$(json_escape "$name")"
  printf '"url":"%s",' "$(json_escape "$url")"
  printf '"category":"%s",' "$(json_escape "$category")"
  printf '"enabled":%s,' "$enabled"
  printf '"timeout":%s,' "$timeout"
  printf '"host":"%s",' "$(json_escape "$host")"
  printf '"dns_ok":%s,' "$dns_ok"
  printf '"http_ok":%s,' "$http_ok"
  printf '"ok":%s,' "$ok"
  printf '"http_code":%s,' "$http_code"
  printf '"time_total":%s,' "$time_total"
  printf '"error_type":"%s",' "$(json_escape "$error_type")"
  printf '"error_message":"%s",' "$(json_escape "$error_message")"
  printf '"checked_at":"%s"' "$(json_escape "$now")"
  printf '}\n'
}

extract_host() {
  url="$1"
  case "$url" in
    http://*|https://*) ;;
    *) return 1 ;;
  esac

  host="${url#http://}"
  host="${host#https://}"
  host="${host%%/*}"
  host="${host%%:*}"

  [ -n "$host" ] || return 1
  case "$host" in
    *[!A-Za-z0-9.-]*|.*|*.) return 1 ;;
  esac

  printf '%s\n' "$host"
}

status_is_success() {
  case "$1" in
    200|204|301|302|304) return 0 ;;
    *) return 1 ;;
  esac
}

name="${1:-}"
url="${2:-}"
category="${3:-}"
enabled="${4:-1}"
timeout="${5:-5}"

case "$timeout" in
  ''|*[!0-9]*) timeout=5 ;;
esac

host="$(extract_host "$url" 2>/dev/null || true)"
if [ -z "$host" ]; then
  emit_json "$name" "$url" "$category" "$enabled" "$timeout" "" false false false 0 0 invalid_url "URL 必须以 http:// 或 https:// 开头"
  exit 0
fi

dns_cmd="${CHECK_DNS_CMD:-}"
if [ -n "$dns_cmd" ]; then
  if ! sh -c "$dns_cmd" >/dev/null 2>&1; then
    emit_json "$name" "$url" "$category" "$enabled" "$timeout" "$host" false false false 0 0 dns_failure "DNS 解析失败"
    exit 0
  fi
elif command -v nslookup >/dev/null 2>&1; then
  if ! nslookup "$host" >/dev/null 2>&1; then
    emit_json "$name" "$url" "$category" "$enabled" "$timeout" "$host" false false false 0 0 dns_failure "DNS 解析失败"
    exit 0
  fi
elif command -v resolveip >/dev/null 2>&1; then
  if ! resolveip "$host" >/dev/null 2>&1; then
    emit_json "$name" "$url" "$category" "$enabled" "$timeout" "$host" false false false 0 0 dns_failure "DNS 解析失败"
    exit 0
  fi
else
  emit_json "$name" "$url" "$category" "$enabled" "$timeout" "$host" false false false 0 0 dns_failure "系统缺少 nslookup 或 resolveip"
  exit 0
fi

curl_cmd="${CHECK_CURL_CMD:-}"
if [ -n "$curl_cmd" ]; then
  curl_output="$(sh -c "$curl_cmd" 2>/dev/null || true)"
else
  curl_output="$(curl -L -k -o /dev/null -sS --connect-timeout "$timeout" --max-time "$timeout" -w '%{http_code}:%{time_total}' "$url" 2>/dev/null || true)"
fi

http_code="${curl_output%%:*}"
time_total="${curl_output#*:}"

case "$http_code" in
  ''|*[!0-9]*) http_code=0 ;;
esac
case "$time_total" in
  ''|*[!0-9.]*|"$curl_output") time_total=0 ;;
esac

if status_is_success "$http_code"; then
  emit_json "$name" "$url" "$category" "$enabled" "$timeout" "$host" true true true "$http_code" "$time_total" "" ""
  exit 0
fi

if [ "$http_code" = 0 ]; then
  emit_json "$name" "$url" "$category" "$enabled" "$timeout" "$host" true false false "$http_code" "$time_total" timeout "解析正常，访问超时或连接失败"
else
  emit_json "$name" "$url" "$category" "$enabled" "$timeout" "$host" true false false "$http_code" "$time_total" http_failure "解析正常，HTTP 状态异常"
fi
```

- [ ] **Step 4: Run checker tests**

Run:

```bash
chmod +x luci-app-ipass/root/usr/share/ipass/check.sh
./tests/check_sh_tests.sh
```

Expected: PASS with `check.sh tests passed`.

- [ ] **Step 5: Run shell syntax checks**

Run:

```bash
sh -n luci-app-ipass/root/usr/share/ipass/check.sh
sh -n tests/check_sh_tests.sh
```

Expected: PASS with no output.

- [ ] **Step 6: Commit**

Run:

```bash
git add luci-app-ipass/root/usr/share/ipass/check.sh tests/check_sh_tests.sh
git commit -m "feat: add connectivity checker"
```

## Task 3: LuCI Controller and JSON Endpoint

**Files:**
- Create: `luci-app-ipass/luasrc/controller/ipass.lua`

- [ ] **Step 1: Create controller**

Create `luci-app-ipass/luasrc/controller/ipass.lua`:

```lua
module("luci.controller.ipass", package.seeall)

local http = require "luci.http"
local jsonc = require "luci.jsonc"
local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()

local function shell_quote(value)
	value = tostring(value or "")
	return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function read_sites()
	local sites = {}

	uci:foreach("ipass", "site", function(section)
		if section.enabled ~= "0" then
			sites[#sites + 1] = {
				id = section[".name"] or "",
				name = section.name or section[".name"] or "",
				url = section.url or "",
				category = section.category or "",
				enabled = section.enabled or "1",
				timeout = section.timeout or "5"
			}
		end
	end)

	return sites
end

local function run_site_check(site)
	local cmd = table.concat({
		"/usr/share/ipass/check.sh",
		shell_quote(site.name),
		shell_quote(site.url),
		shell_quote(site.category),
		shell_quote(site.enabled),
		shell_quote(site.timeout)
	}, " ")

	local output = sys.exec(cmd)
	local decoded = jsonc.parse(output)

	if type(decoded) ~= "table" then
		return {
			name = site.name,
			url = site.url,
			category = site.category,
			enabled = tonumber(site.enabled) or 1,
			timeout = tonumber(site.timeout) or 5,
			host = "",
			dns_ok = false,
			http_ok = false,
			ok = false,
			http_code = 0,
			time_total = 0,
			error_type = "internal_error",
			error_message = "检测脚本返回了无效结果",
			checked_at = os.date("%Y-%m-%d %H:%M:%S")
		}
	end

	decoded.id = site.id
	return decoded
end

function index()
	if not nixio.fs.access("/etc/config/ipass") then
		return
	end

	entry({"admin", "services", "ipass"}, template("ipass/status"), _("iPass"), 60).dependent = true
	entry({"admin", "services", "ipass", "sites"}, cbi("ipass/sites"), _("站点配置"), 61).leaf = true
	entry({"admin", "services", "ipass", "check"}, call("action_check")).leaf = true
end

function action_check()
	local results = {}
	local sites = read_sites()

	for _, site in ipairs(sites) do
		results[#results + 1] = run_site_check(site)
	end

	http.prepare_content("application/json")
	http.write_json({
		ok = true,
		count = #results,
		results = results
	})
end
```

- [ ] **Step 2: Run Lua syntax check**

Run:

```bash
lua -e 'assert(loadfile("luci-app-ipass/luasrc/controller/ipass.lua"))'
```

Expected: PASS with no output when local `lua` is installed. If local `lua` is unavailable, record that this syntax check is deferred to OpenWrt SDK compile.

- [ ] **Step 3: Commit**

Run:

```bash
git add luci-app-ipass/luasrc/controller/ipass.lua
git commit -m "feat: add ipass luci controller"
```

## Task 4: Site Configuration Page

**Files:**
- Create: `luci-app-ipass/luasrc/model/cbi/ipass/sites.lua`

- [ ] **Step 1: Create CBI model**

Create `luci-app-ipass/luasrc/model/cbi/ipass/sites.lua`:

```lua
local m
local s
local o

m = Map("ipass", translate("iPass - 站点配置"))
m.description = translate("管理需要从路由器检测连通性的站点。")

s = m:section(TypedSection, "site", translate("站点"))
s.addremove = true
s.anonymous = false
s.template = "cbi/tblsection"

o = s:option(Flag, "enabled", translate("启用"))
o.default = "1"
o.rmempty = false

o = s:option(Value, "name", translate("名称"))
o.placeholder = translate("Google 204")
o.rmempty = false

o = s:option(Value, "url", translate("URL"))
o.placeholder = "https://www.google.com/generate_204"
o.rmempty = false
o.validate = function(self, value, section)
	if value:match("^https?://[%w%.%-]+[:%d]*/?.*") then
		return value
	end
	return nil, translate("URL 必须以 http:// 或 https:// 开头")
end

o = s:option(Value, "category", translate("分类"))
o.placeholder = translate("国内")
o.default = translate("自定义")
o.rmempty = false

o = s:option(Value, "timeout", translate("超时秒数"))
o.datatype = "uinteger"
o.default = "5"
o.rmempty = false
o.validate = function(self, value, section)
	local n = tonumber(value)
	if n and n >= 1 and n <= 30 then
		return tostring(math.floor(n))
	end
	return nil, translate("超时秒数必须在 1 到 30 之间")
end

return m
```

- [ ] **Step 2: Run Lua syntax check**

Run:

```bash
lua -e 'assert(loadfile("luci-app-ipass/luasrc/model/cbi/ipass/sites.lua"))'
```

Expected: PASS with no output when local `lua` is installed. If local `lua` is unavailable, record that this syntax check is deferred to OpenWrt SDK compile.

- [ ] **Step 3: Commit**

Run:

```bash
git add luci-app-ipass/luasrc/model/cbi/ipass/sites.lua
git commit -m "feat: add ipass site configuration page"
```

## Task 5: Status Page UI

**Files:**
- Create: `luci-app-ipass/luasrc/view/ipass/status.htm`

- [ ] **Step 1: Create status template**

Create `luci-app-ipass/luasrc/view/ipass/status.htm`:

```html
<%+header%>

<style>
.ipass-toolbar {
	display: flex;
	align-items: center;
	justify-content: space-between;
	gap: 12px;
	margin: 16px 0;
}
.ipass-summary {
	font-size: 16px;
	font-weight: 600;
}
.ipass-actions {
	display: flex;
	gap: 8px;
}
.ipass-grid {
	display: grid;
	grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
	gap: 12px;
}
.ipass-card {
	border: 1px solid #d8d8d8;
	border-radius: 6px;
	padding: 12px;
	background: #fff;
}
.ipass-card.ok {
	border-color: #47a447;
}
.ipass-card.fail {
	border-color: #d9534f;
}
.ipass-card.checking {
	border-color: #f0ad4e;
}
.ipass-card-title {
	display: flex;
	align-items: center;
	justify-content: space-between;
	gap: 8px;
	margin-bottom: 8px;
}
.ipass-name {
	font-size: 15px;
	font-weight: 600;
}
.ipass-category {
	color: #666;
	font-size: 12px;
}
.ipass-url {
	color: #666;
	font-size: 12px;
	overflow-wrap: anywhere;
	margin-bottom: 8px;
}
.ipass-row {
	display: flex;
	justify-content: space-between;
	gap: 8px;
	font-size: 13px;
	line-height: 1.8;
}
.ipass-muted {
	color: #777;
}
.ipass-error {
	color: #b94a48;
	margin-top: 8px;
	font-size: 13px;
}
</style>

<h2 name="content"><%:iPass%></h2>

<div class="ipass-toolbar">
	<div id="ipass-summary" class="ipass-summary">未检测</div>
	<div class="ipass-actions">
		<a class="btn cbi-button" href="<%=url('admin/services/ipass/sites')%>">站点配置</a>
		<button id="ipass-check" class="btn cbi-button cbi-button-apply">重新检测</button>
	</div>
</div>

<div id="ipass-grid" class="ipass-grid"></div>

<script type="text/javascript">
(function() {
	'use strict';

	var grid = document.getElementById('ipass-grid');
	var summary = document.getElementById('ipass-summary');
	var button = document.getElementById('ipass-check');
	var endpoint = '<%=url("admin/services/ipass/check")%>';

	function text(value) {
		return value === undefined || value === null || value === '' ? '-' : String(value);
	}

	function setSummary(results, running) {
		if (running) {
			summary.textContent = '检测中';
			return;
		}
		if (!results || results.length === 0) {
			summary.textContent = '未检测';
			return;
		}
		var failed = results.filter(function(item) { return !item.ok; }).length;
		summary.textContent = failed === 0 ? '全部可达' : '部分异常：' + failed + ' 个站点异常';
	}

	function renderChecking() {
		grid.innerHTML = '<div class="ipass-card checking"><div class="ipass-name">检测中</div><div class="ipass-muted">正在从路由器发起 DNS 和 HTTP/HTTPS 检测。</div></div>';
	}

	function renderResults(results) {
		grid.innerHTML = '';
		results.forEach(function(item) {
			var card = document.createElement('div');
			card.className = 'ipass-card ' + (item.ok ? 'ok' : 'fail');
			card.innerHTML =
				'<div class="ipass-card-title">' +
					'<div class="ipass-name"></div>' +
					'<div class="ipass-category"></div>' +
				'</div>' +
				'<div class="ipass-url"></div>' +
				'<div class="ipass-row"><span>DNS</span><strong class="dns"></strong></div>' +
				'<div class="ipass-row"><span>HTTP</span><strong class="http"></strong></div>' +
				'<div class="ipass-row"><span>耗时</span><span class="time"></span></div>' +
				'<div class="ipass-row"><span>检测时间</span><span class="checked"></span></div>' +
				'<div class="ipass-error"></div>';

			card.querySelector('.ipass-name').textContent = text(item.name);
			card.querySelector('.ipass-category').textContent = text(item.category);
			card.querySelector('.ipass-url').textContent = text(item.url);
			card.querySelector('.dns').textContent = item.dns_ok ? '正常' : '失败';
			card.querySelector('.http').textContent = item.http_ok ? '正常 ' + text(item.http_code) : '失败';
			card.querySelector('.time').textContent = item.time_total ? item.time_total + ' 秒' : '-';
			card.querySelector('.checked').textContent = text(item.checked_at);
			card.querySelector('.ipass-error').textContent = item.ok ? '' : text(item.error_message || item.error_type);
			grid.appendChild(card);
		});
	}

	function runCheck() {
		button.disabled = true;
		setSummary([], true);
		renderChecking();

		fetch(endpoint, { credentials: 'same-origin' })
			.then(function(response) { return response.json(); })
			.then(function(payload) {
				var results = payload && payload.results ? payload.results : [];
				renderResults(results);
				setSummary(results, false);
			})
			.catch(function() {
				grid.innerHTML = '<div class="ipass-card fail"><div class="ipass-name">检测失败</div><div class="ipass-error">无法调用检测接口。</div></div>';
				summary.textContent = '部分异常';
			})
			.finally(function() {
				button.disabled = false;
			});
	}

	button.addEventListener('click', runCheck);
	runCheck();
}());
</script>

<%+footer%>
```

- [ ] **Step 2: Check template contains required behavior**

Run:

```bash
grep -q 'runCheck();' luci-app-ipass/luasrc/view/ipass/status.htm
grep -q '重新检测' luci-app-ipass/luasrc/view/ipass/status.htm
grep -q 'admin/services/ipass/check' luci-app-ipass/luasrc/view/ipass/status.htm
```

Expected: PASS with no output.

- [ ] **Step 3: Commit**

Run:

```bash
git add luci-app-ipass/luasrc/view/ipass/status.htm
git commit -m "feat: add ipass status page"
```

## Task 6: Repository Checks and README

**Files:**
- Modify: `scripts/static-check.sh`
- Modify: `README.md`

- [ ] **Step 1: Run complete static check**

Run:

```bash
./scripts/static-check.sh
```

Expected: PASS with `static check passed`.

- [ ] **Step 2: Update README**

Replace `README.md` with:

```markdown
# ipass

`ipass` is a lightweight LuCI connectivity check plugin for OpenWrt/iStoreOS.

## Features

- Chinese LuCI page for router-side website reachability checks.
- Page-load automatic checks.
- One-click manual recheck.
- DNS resolution plus HTTP/HTTPS access checks.
- 8 default site cards: 4 domestic and 4 international.
- User-managed custom site cards through UCI/LuCI.
- No daemon and no scheduled background task.

## Target

- iStoreOS 24.10.x
- OpenWrt 24.10 SDK
- CI build target: `aarch64_generic`
- Target devices include Rockchip R2S, R4S, R5S, R6S, and EasePi-R1.

The LuCI package itself is architecture-independent and produces an `_all.ipk`.

## Local Checks

```bash
./tests/check_sh_tests.sh
./scripts/static-check.sh
```

## Package Layout

```text
luci-app-ipass/
  Makefile
  luasrc/
  root/
```

## GitHub Actions

The build workflow runs only on `main` branch pushes and manual dispatch. It builds the package with the OpenWrt 24.10 `aarch64_generic` SDK and uploads the generated `.ipk`.
```

- [ ] **Step 3: Run local checks**

Run:

```bash
./tests/check_sh_tests.sh
./scripts/static-check.sh
```

Expected: both commands PASS.

- [ ] **Step 4: Commit**

Run:

```bash
git add README.md scripts/static-check.sh
git commit -m "docs: document ipass usage and checks"
```

## Task 7: GitHub Actions SDK Build

**Files:**
- Create: `.github/workflows/build.yml`

- [ ] **Step 1: Create workflow**

Create `.github/workflows/build.yml`:

```yaml
name: Build luci-app-ipass

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  build:
    runs-on: ubuntu-24.04

    env:
      SDK_URL: https://downloads.openwrt.org/releases/24.10.0/targets/armsr/armv8/openwrt-sdk-24.10.0-armsr-armv8_gcc-13.3.0_musl.Linux-x86_64.tar.zst
      SDK_DIR: openwrt-sdk-24.10.0-armsr-armv8_gcc-13.3.0_musl.Linux-x86_64

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install build dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y build-essential clang flex bison g++ gawk gcc-multilib gettext git libncurses5-dev libssl-dev python3-distutils rsync unzip zlib1g-dev file wget zstd

      - name: Run repository checks
        run: |
          chmod +x ./tests/check_sh_tests.sh ./scripts/static-check.sh
          ./tests/check_sh_tests.sh
          ./scripts/static-check.sh

      - name: Download OpenWrt SDK
        run: |
          wget -O sdk.tar.zst "$SDK_URL"
          tar --zstd -xf sdk.tar.zst

      - name: Install package into SDK
        run: |
          mkdir -p "$SDK_DIR/package/luci-app-ipass"
          rsync -a --delete luci-app-ipass/ "$SDK_DIR/package/luci-app-ipass/"

      - name: Update feeds
        working-directory: ${{ env.SDK_DIR }}
        run: |
          ./scripts/feeds update -a
          ./scripts/feeds install -a

      - name: Configure package
        working-directory: ${{ env.SDK_DIR }}
        run: |
          make defconfig
          echo "CONFIG_PACKAGE_luci-app-ipass=m" >> .config
          make defconfig

      - name: Build package
        working-directory: ${{ env.SDK_DIR }}
        run: make package/luci-app-ipass/compile V=s

      - name: Collect artifacts
        run: |
          mkdir -p artifacts
          find "$SDK_DIR/bin/packages" -name 'luci-app-ipass*.ipk' -exec cp {} artifacts/ \;
          test -n "$(find artifacts -name 'luci-app-ipass*.ipk' -print -quit)"

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: luci-app-ipass-ipk
          path: artifacts/*.ipk
```

- [ ] **Step 2: Verify workflow trigger is main-only**

Run:

```bash
grep -q 'branches: \[main\]' .github/workflows/build.yml
grep -q 'workflow_dispatch:' .github/workflows/build.yml
```

Expected: PASS with no output.

- [ ] **Step 3: Commit**

Run:

```bash
git add .github/workflows/build.yml
git commit -m "ci: build ipass package on main"
```

## Task 8: iStore `.run` Wrapper

**Files:**
- Create: `scripts/package-run.sh`

- [ ] **Step 1: Create wrapper script**

Create `scripts/package-run.sh`:

```sh
#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <input.ipk> <output.run>" >&2
  exit 1
fi

input_ipk="$1"
output_run="$2"

if [ ! -f "$input_ipk" ]; then
  echo "input ipk not found: $input_ipk" >&2
  exit 1
fi

tmp_payload="$(mktemp)"
base64 "$input_ipk" > "$tmp_payload"

cat > "$output_run" <<'HEADER'
#!/bin/sh
set -eu

tmp_dir="$(mktemp -d /tmp/ipass-install.XXXXXX)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

payload="$tmp_dir/luci-app-ipass.ipk"
sed '1,/^__IPK_PAYLOAD__$/d' "$0" | base64 -d > "$payload"

if command -v opkg >/dev/null 2>&1; then
  opkg install "$payload"
else
  echo "opkg not found; this installer must run on OpenWrt/iStoreOS" >&2
  exit 1
fi

exit 0
__IPK_PAYLOAD__
HEADER

cat "$tmp_payload" >> "$output_run"
rm -f "$tmp_payload"
chmod +x "$output_run"
echo "created $output_run"
```

- [ ] **Step 2: Run syntax check**

Run:

```bash
chmod +x scripts/package-run.sh
sh -n scripts/package-run.sh
```

Expected: PASS with no output.

- [ ] **Step 3: Test wrapper creation with a dummy payload**

Run:

```bash
printf 'dummy ipk\n' > /tmp/luci-app-ipass-test.ipk
./scripts/package-run.sh /tmp/luci-app-ipass-test.ipk /tmp/luci-app-ipass-test.run
test -x /tmp/luci-app-ipass-test.run
grep -q '__IPK_PAYLOAD__' /tmp/luci-app-ipass-test.run
```

Expected: PASS and output `created /tmp/luci-app-ipass-test.run`.

- [ ] **Step 4: Commit**

Run:

```bash
git add scripts/package-run.sh
git commit -m "build: add istore run package wrapper"
```

## Task 9: End-to-End Verification

**Files:**
- Modify: `.github/workflows/build.yml` if CI exposes SDK URL drift.
- Modify: `README.md` if verification reveals install details that users need.

- [ ] **Step 1: Run all local checks**

Run:

```bash
./tests/check_sh_tests.sh
./scripts/static-check.sh
sh -n scripts/package-run.sh
```

Expected: all commands PASS.

- [ ] **Step 2: Run local SDK build when bandwidth and disk are available**

Run:

```bash
SDK_URL='https://downloads.openwrt.org/releases/24.10.0/targets/armsr/armv8/openwrt-sdk-24.10.0-armsr-armv8_gcc-13.3.0_musl.Linux-x86_64.tar.zst'
wget -O /tmp/ipass-sdk.tar.zst "$SDK_URL"
tar --zstd -xf /tmp/ipass-sdk.tar.zst -C /tmp
SDK_DIR='/tmp/openwrt-sdk-24.10.0-armsr-armv8_gcc-13.3.0_musl.Linux-x86_64'
mkdir -p "$SDK_DIR/package/luci-app-ipass"
rsync -a --delete luci-app-ipass/ "$SDK_DIR/package/luci-app-ipass/"
cd "$SDK_DIR"
./scripts/feeds update -a
./scripts/feeds install -a
make defconfig
echo "CONFIG_PACKAGE_luci-app-ipass=m" >> .config
make defconfig
make package/luci-app-ipass/compile V=s
find bin/packages -name 'luci-app-ipass*.ipk' -print
```

Expected: build completes and prints a `luci-app-ipass_0.1.0-1_all.ipk` path.

- [ ] **Step 3: Create `.run` package from built `.ipk`**

Run:

```bash
IPK_PATH="$(find "$SDK_DIR/bin/packages" -name 'luci-app-ipass*.ipk' -print -quit)"
cd /Users/yiwei/ipass
./scripts/package-run.sh "$IPK_PATH" /tmp/luci-app-ipass_0.1.0-1_all_sdk_24.10.run
test -x /tmp/luci-app-ipass_0.1.0-1_all_sdk_24.10.run
```

Expected: PASS and `.run` file exists.

- [ ] **Step 4: Manual router verification**

On iStoreOS 24.10.x:

```sh
opkg install /tmp/luci-app-ipass_0.1.0-1_all.ipk
/etc/init.d/uhttpd restart
```

Expected:

- LuCI menu shows `服务 -> iPass`.
- Opening the page automatically starts detection.
- `重新检测` refreshes results.
- The config page can add, edit, delete, enable, and disable sites.
- No new daemon appears in `ps`.

- [ ] **Step 5: Commit verification docs if changed**

Run:

```bash
git status --short
git add README.md .github/workflows/build.yml
git commit -m "docs: record ipass verification notes"
```

Expected: only run this commit if Task 9 changed files.

