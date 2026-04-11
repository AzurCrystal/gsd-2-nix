#!/usr/bin/env bash
set -euo pipefail

# `homeManagerModules` is a common community flake output, but it is not one of
# the output names that `nix flake check` treats as built-in, so Nix emits an
# "unknown flake output" warning even when the output is intentionally exposed.
exec nix flake check -L "$@" \
  2> >(grep -vFx "warning: unknown flake output 'homeManagerModules'" >&2)
