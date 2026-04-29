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
base64 < "$input_ipk" > "$tmp_payload"

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
