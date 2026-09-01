#!/usr/bin/env bash

set -euo pipefail

{
  printf '%s\n' '@NAME@'
  printf '%s\n' "$@"
} >>'@CALL_LOG@'
