# ipass LuCI Connectivity Plugin Design

## Summary

Build a lightweight LuCI plugin for OpenWrt/iStoreOS named `luci-app-ipass`. The plugin tests whether the router itself can resolve and access a configurable set of websites. It targets iStoreOS 24.10.x on Rockchip devices such as R2S, R4S, R5S, R6S, and EasePi-R1, using the OpenWrt 24.10 `aarch64_generic` SDK for CI validation.

The first version is deliberately small: no daemon, no scheduled background checks, no history database, and no multilingual UI. Each page visit triggers a fresh check, and users can also run checks manually from the page.

## Confirmed Scope

- Chinese-only LuCI interface.
- Default site cards: 8 total, 4 domestic and 4 international.
- User-managed custom sites.
- Check type: DNS resolution plus HTTP/HTTPS access.
- Page load automatically checks all enabled sites.
- A button manually rechecks all enabled sites.
- Unified success rule for all sites.
- GitHub Actions support, running only on `main` branch pushes and manual dispatch.
- Package output as `.ipk` first, with `.run` iStore wrapper as a follow-up packaging step.

## Non-Goals

- No scheduled checks.
- No always-running service.
- No long-term history chart.
- No per-site expected status-code configuration.
- No proxy, firewall, routing, or DNS modification features.
- No dependency on Passwall internals.

## Product Behavior

The LuCI menu entry is named `iPass`, placed under either `服务` or `网络`. The main page shows an overall status at the top:

- `检测中`
- `全部可达`
- `部分异常`
- `未检测`

Below the summary, the page renders site cards. Each card displays:

- Name
- Category
- URL
- DNS status
- HTTP status
- Response time
- Last check time
- Error summary

Opening the page starts one check for all enabled sites. Clicking `重新检测` starts another check and refreshes the cards without requiring a full page reload.

Users can add, edit, delete, enable, and disable site cards. The first version keeps configuration simple: users provide name, URL, category, enabled state, and timeout.

## Default Sites

Domestic:

- Baidu: `https://www.baidu.com/`
- Tencent: `https://www.qq.com/`
- Aliyun: `https://www.aliyun.com/`
- Bilibili: `https://www.bilibili.com/`

International:

- Google 204: `https://www.google.com/generate_204`
- GitHub: `https://github.com/`
- Cloudflare: `https://www.cloudflare.com/`
- Wikipedia: `https://www.wikipedia.org/`

These defaults are installed through UCI defaults only when `/etc/config/ipass` does not already exist or does not contain site sections.

## Success Rules

The check logic is shared across all sites:

- DNS resolution must succeed.
- HTTP/HTTPS request must complete before timeout.
- HTTP status `200`, `204`, `301`, `302`, or `304` is considered reachable.

Errors are grouped into user-facing categories:

- DNS failure
- Timeout
- TLS or connection failure
- HTTP failure
- Invalid URL

If DNS succeeds but HTTP fails, the card should explicitly show that resolution worked but access failed.

## Package Structure

```text
ipass/
  luci-app-ipass/
    Makefile
    luasrc/
      controller/ipass.lua
      model/cbi/ipass/
        sites.lua
      view/ipass/
        status.htm
    root/
      etc/config/ipass
      etc/uci-defaults/90_luci-ipass
      usr/share/ipass/check.sh
      usr/share/ipass/defaults.json
  .github/workflows/build.yml
  scripts/
    package-run.sh
  README.md
```

The package should use the standard LuCI package include:

```make
include $(TOPDIR)/feeds/luci/luci.mk
```

The LuCI package architecture should be `all`, because the plugin contains Lua, shell, static view files, and UCI config only. CI still builds it with the 24.10 `aarch64_generic` SDK to validate the target platform.

## Dependencies

Minimal dependency set:

```make
LUCI_DEPENDS:=+curl +luci-compat +libuci-lua +luci-lib-jsonc
LUCI_PKGARCH:=all
```

DNS resolution should use a command available on iStoreOS/OpenWrt by default when possible. If runtime validation shows BusyBox `nslookup` is unavailable or inconsistent, add a small explicit dependency such as `resolveip`.

## UCI Data Model

Each configured site is a UCI `site` section:

```text
config site
  option name 'Google'
  option url 'https://www.google.com/generate_204'
  option category '国际'
  option enabled '1'
  option timeout '5'
```

Fields:

- `name`: display name.
- `url`: HTTP or HTTPS URL.
- `category`: free text category, with defaults `国内` and `国际`.
- `enabled`: `1` or `0`.
- `timeout`: request timeout in seconds, default `5`.

## Backend Interfaces

The LuCI controller exposes:

- Main status page.
- Configuration page for site management.
- JSON endpoint to run checks for enabled sites.

The endpoint reads UCI config, calls `/usr/share/ipass/check.sh`, and returns JSON suitable for direct card rendering.

`check.sh` responsibilities:

- Validate URL.
- Extract hostname.
- Resolve hostname.
- Run `curl` with timeout and status reporting.
- Emit compact JSON per site or per request.

The shell script must not write history files or spawn background processes.

## Frontend Behavior

The status page can be implemented with a LuCI template plus small page-local JavaScript:

- On load, call the check endpoint.
- Set all cards to `检测中`.
- Render DNS status, HTTP status, latency, and error text from JSON.
- Disable the recheck button while a check is running.
- Re-enable it after completion or failure.

The UI should keep all explanatory text concise and operational. It should not include long in-page documentation.

## GitHub Actions

The workflow runs only on `main` branch pushes and manual dispatch:

```yaml
on:
  push:
    branches: [main]
  workflow_dispatch:
```

Initial CI responsibilities:

- Download or cache the OpenWrt 24.10 `aarch64_generic` SDK.
- Copy `luci-app-ipass` into the SDK package directory or a local feed.
- Update and install feeds as needed.
- Run `make package/luci-app-ipass/compile V=s`.
- Upload generated `.ipk` artifacts.

Follow-up packaging:

- `scripts/package-run.sh` wraps the `.ipk` into a shell `.run` installer for iStore manual installation.
- The `.run` package installs by extracting the embedded `.ipk` and running `opkg install`.

## Verification

Development verification:

- Shell script URL parsing and result formatting tests.
- Static package structure checks.
- OpenWrt SDK package compile.

Manual or device verification:

- Install generated `.ipk` on iStoreOS 24.10.x.
- Confirm LuCI menu entry appears.
- Confirm page load runs checks automatically.
- Confirm `重新检测` refreshes all enabled cards.
- Confirm DNS failure and HTTP failure produce different messages.
- Confirm users can add, edit, delete, enable, and disable sites.
- Confirm no daemon or recurring process is installed.

## Implementation Phases

1. MVP package skeleton: Makefile, LuCI menu, default UCI config, Chinese page.
2. Detection backend: UCI reading, DNS plus HTTP checks, JSON output.
3. Status page interaction: auto-check, manual recheck, card rendering.
4. Site configuration: add, edit, delete, enable, disable.
5. CI package build: OpenWrt 24.10 `aarch64_generic` SDK artifact.
6. iStore packaging: `.run` wrapper script.
7. Device validation: Rockchip/iStoreOS 24.10.x install and behavior test.

