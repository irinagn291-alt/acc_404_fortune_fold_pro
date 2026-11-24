#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
temporary="$(mktemp -d "${TMPDIR:-/tmp}/acc404-rules.XXXXXXXX")"
trap 'rm -rf -- "$temporary"' EXIT
evidence="${FF_EVIDENCE_ROOT:?Set FF_EVIDENCE_ROOT outside the project}"
mkdir -p "$evidence"
swiftc -module-cache-path "$temporary/modules" FortuneFold/Paper.swift QA/StreamPilot.swift -o "$temporary/stream"
"$temporary/stream" | tee "$evidence/stream-pilot.txt"
swiftc -module-cache-path "$temporary/modules" FortuneFold/Paper.swift QA/VerifyCampaign.swift -o "$temporary/campaign"
"$temporary/campaign" | tee "$evidence/campaign.txt"
