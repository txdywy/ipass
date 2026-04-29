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

if [ -z "$curl_output" ]; then
  emit_json "$name" "$url" "$category" "$enabled" "$timeout" "$host" true false false 0 0 http_failure "解析正常，HTTP 检测失败"
  exit 0
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
