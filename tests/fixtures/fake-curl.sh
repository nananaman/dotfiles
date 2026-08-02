#!/usr/bin/env bash
set -euo pipefail

printf 'HTTP/2 %s\r\n%s: %s\r\n\r\n' \
  "${FAKE_CURL_STATUS:-200}" "${FAKE_CURL_REVISION_HEADER:-X-Host-Artifact-Revision}" \
  "${FAKE_CURL_RESPONSE_REVISION:-$FAKE_CURL_REVISION}"
printf 'Host-Artifact-Status: %s\n' "${FAKE_CURL_STATUS:-200}"
