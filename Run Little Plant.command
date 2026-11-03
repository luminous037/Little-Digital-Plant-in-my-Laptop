#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
./scripts/build-app.sh
open "dist/Little Plant.app"
