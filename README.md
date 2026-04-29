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
