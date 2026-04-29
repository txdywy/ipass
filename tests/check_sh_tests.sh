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
