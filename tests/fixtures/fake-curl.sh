#!/usr/bin/env bash
set -euo pipefail

printf 'HTTP/2 %s\r\nX-Host-Artifact-Revision: %s\r\n\r\n' "${FAKE_CURL_STATUS:-200}" "$FAKE_CURL_REVISION"
printf 'Host-Artifact-Status: %s\n' "${FAKE_CURL_STATUS:-200}"
