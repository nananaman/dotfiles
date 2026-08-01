set -euo pipefail

tailscale_bin=""
if [ -x "@TAILSCALE_WRAPPER@" ]; then
  tailscale_bin="@TAILSCALE_WRAPPER@"
elif [ -x "@TAILSCALE_APP@" ]; then
  tailscale_bin="@TAILSCALE_APP@"
fi
curl_bin="@CURL@"
jq_bin="@JQ@"
grep_bin="@GREP@"
tr_bin="@TR@"
target="http://127.0.0.1:9417"

unavailable() {
  "$jq_bin" -cn --arg reason "$1" '{schemaVersion:1,available:false,configured:false,reason:$reason}'
}

inspect() {
  if [ -z "$tailscale_bin" ]; then unavailable "tailscale-not-installed"; return; fi
  if ! status_json="$($tailscale_bin status --json 2>/dev/null)"; then
    echo "host-artifact-tailscale: status failed" >&2
    return 1
  fi
  if ! printf '%s' "$status_json" | "$jq_bin" -e '.Self.Online == true and (.Self.DNSName | type == "string")' >/dev/null 2>&1; then
    unavailable "tailscale-offline"; return
  fi
  dns_name="$(printf '%s' "$status_json" | "$jq_bin" -r '.Self.DNSName | sub("[.]$";"")')"
  dns_name="$(printf '%s' "$dns_name" | "$tr_bin" '[:upper:]' '[:lower:]')"
  if [ -z "$dns_name" ] || [ "${#dns_name}" -gt 253 ] || \
    [[ ! "$dns_name" =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]; then
    echo "host-artifact-tailscale: invalid Self.DNSName" >&2
    return 1
  fi
  if ! serve_json="$($tailscale_bin serve status --json 2>/dev/null)"; then
    echo "host-artifact-tailscale: serve status failed" >&2
    return 1
  fi
  if ! printf '%s' "$serve_json" | "$jq_bin" -e . >/dev/null 2>&1; then
    echo "host-artifact-tailscale: malformed serve status" >&2; return 1
  fi
  root_state="$(printf '%s' "$serve_json" | "$jq_bin" -r --arg target "$target" --arg webKey "$dns_name:443" '
    [.Web[$webKey]?.Handlers? | select(type == "object") | .["/"]? | select(. != null)] as $handlers
    | if ($handlers | length) == 0 then "empty"
      elif all($handlers[]; type == "object" and keys == ["Proxy"] and .Proxy == $target) then "configured"
      else "conflict"
      end
  ' 2>/dev/null)"
  if [ "$root_state" = "configured" ]; then
    "$jq_bin" -cn --arg origin "https://$dns_name" '{schemaVersion:1,available:true,configured:true,origin:$origin}'
  elif [ "$root_state" = "empty" ]; then
    "$jq_bin" -cn '{schemaVersion:1,available:true,configured:false,reason:"serve-unconfigured"}'
  else
    echo "host-artifact-tailscale: conflicting root Serve target" >&2; return 1
  fi
}

case "${1:-}" in
  inspect)
    [ "$#" -eq 1 ] || { echo "usage: host-artifact-tailscale inspect" >&2; exit 64; }
    inspect
    ;;
  setup)
    [ "$#" -eq 1 ] || { echo "usage: host-artifact-tailscale setup" >&2; exit 64; }
    before="$(inspect)" || exit $?
    if ! printf '%s' "$before" | "$jq_bin" -e '.available == true' >/dev/null; then printf '%s\n' "$before"; exit 0; fi
    if printf '%s' "$before" | "$jq_bin" -e '.configured == true' >/dev/null; then printf '%s\n' "$before"; exit 0; fi
    "$tailscale_bin" serve --bg --https=443 "$target" >/dev/null
    inspect
    ;;
  verify)
    [ "$#" -eq 4 ] || { echo "usage: host-artifact-tailscale verify WORKSPACE ARTIFACT REVISION" >&2; exit 64; }
    workspace="$2"; artifact="$3"; revision="$4"
    [[ "$workspace" =~ ^[a-z0-9][a-z0-9-]{0,47}~[a-f0-9]{12}$ ]] || exit 64
    [[ "$artifact" =~ ^[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$ ]] || exit 64
    [[ "$artifact" != *--* ]] || exit 64
    [[ "$revision" =~ ^r-[a-f0-9]{32}$ ]] || exit 64
    state="$(inspect)" || exit $?
    if ! origin="$(printf '%s' "$state" | "$jq_bin" -er 'select(.configured == true) | .origin')"; then
      "$jq_bin" -cn '{schemaVersion:1,verified:false,reason:"serve-unavailable"}'
      exit 0
    fi
    url="$origin/a/$workspace/$artifact/"
    response="$($curl_bin --silent --show-error --max-time 3 --retry 2 --head \
      --write-out 'Host-Artifact-Status: %{http_code}\n' "$url" 2>/dev/null || true)"
    if printf '%s\n' "$response" | "$tr_bin" -d '\r' | "$grep_bin" -Eq '^Host-Artifact-Status: 2[0-9][0-9]$' && \
      printf '%s\n' "$response" | "$tr_bin" -d '\r' | "$grep_bin" -Fqx "X-Host-Artifact-Revision: $revision"; then
      "$jq_bin" -cn --arg url "$url" '{schemaVersion:1,verified:true,url:$url}'
    else
      "$jq_bin" -cn '{schemaVersion:1,verified:false,reason:"remote-verification-failed"}'
    fi
    ;;
  *) echo "usage: host-artifact-tailscale <inspect|setup|verify WORKSPACE ARTIFACT REVISION>" >&2; exit 64 ;;
esac
