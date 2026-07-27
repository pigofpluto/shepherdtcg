#!/bin/bash
# Headless engine checks. Compiles the model/engine sources for macOS together
# with Tests/EngineProbe.swift and runs every rule assertion.
#
#   ./Tests/run-probe.sh
#
# Tests/ is deliberately NOT in project.yml sources — it must never ship in the app.
set -e
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)
swiftc -parse-as-library \
  Models/TCGCard.swift Models/MatchModels.swift \
  Services/CardLibrary.swift ViewModels/MatchViewModel.swift \
  Tests/EngineProbe.swift -o "$OUT/probe"
"$OUT/probe"
