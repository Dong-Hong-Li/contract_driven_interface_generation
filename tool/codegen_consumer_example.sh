#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root/examples/consumer"
dart pub get
dart run contract_driven_interface_generation
dart run build_runner build --delete-conflicting-outputs
