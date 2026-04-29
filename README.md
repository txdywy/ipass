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
- CI build targets: `armsr-armv8`, `rockchip-armv8`, `mediatek-filogic`, `ramips-mt7621`, and `x86-64`
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

The build workflow runs on `main` branch pushes, `v*` tag pushes, and manual dispatch. It builds with multiple OpenWrt 24.10 SDK targets and uploads both `.ipk` and self-installing `.run` artifacts.

Pushing a version tag publishes a GitHub Release automatically:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Release asset names include the OpenWrt SDK target, for example `luci-app-ipass_0.1.0-1_all-rockchip-armv8.ipk` and `luci-app-ipass_0.1.0-1_all-rockchip-armv8.run`.
