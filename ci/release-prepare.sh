#!/bin/bash

set -euo pipefail

: "${LANGUAGE:?LANGUAGE is required (java, nodejs, or python)}"
: "${VERSION:?VERSION is required (e.g. 1.41.0)}"

VERSION_DASHED="v${VERSION//./-}"
TAG="${LANGUAGE}-v${VERSION}"
RELEASE_BRANCH="release-${TAG}"
DATE="$(date +%Y-%m-%d)"

LAYER_DATA="${LANGUAGE}/layer-data.sh"
TEMPLATE="${LANGUAGE}/sample-apps/template.yaml"

# Clean up .bak files on exit (including early exits)
cleanup() { find . -maxdepth 3 -name '*.bak' -delete; }
trap cleanup EXIT

OLD_VERSION_DASHED=$(grep '^VERSION=' "${LAYER_DATA}" | cut -d= -f2)
if [[ -z "${OLD_VERSION_DASHED}" ]]; then
  echo "ERROR: could not extract VERSION from ${LAYER_DATA}" >&2
  exit 1
fi

# --- Update CHANGELOG.md ---

cat > /tmp/changelog_block.md <<EOF

## [${TAG}]

### Released ${DATE}

### Changed

- TODO: fill in changelog

[${TAG}]: https://github.com/SumoLogic/sumologic-otel-lambda/releases/tag/${TAG}
EOF

if ! grep -q '^All notable changes' CHANGELOG.md; then
  echo "ERROR: could not find 'All notable changes' header in CHANGELOG.md" >&2
  exit 1
fi
sed -i.bak "/^All notable changes/r /tmp/changelog_block.md" CHANGELOG.md

# --- Update layer-data.sh ---

sed -i.bak "s|^VERSION=.*|VERSION=${VERSION_DASHED}|" "${LAYER_DATA}"

sed -i.bak \
  "s|tree/[^/]*/\{0,1\}${LANGUAGE}|tree/${RELEASE_BRANCH}/${LANGUAGE}|" \
  "${LAYER_DATA}"

# --- Update template.yaml ---

sed -i.bak "s|${OLD_VERSION_DASHED}|${VERSION_DASHED}|g" "${TEMPLATE}"

# --- Detect component versions from submodule ---

COLLECTOR_VERSION=$(grep "go.opentelemetry.io/collector/otelcol v" \
  opentelemetry-lambda/collector/go.mod | awk '{print $2}')
if [[ -z "${COLLECTOR_VERSION}" ]]; then
  echo "ERROR: could not extract COLLECTOR_VERSION from collector/go.mod" >&2
  exit 1
fi

case "${LANGUAGE}" in
  python)
    SDK_VERSION=$(grep "^opentelemetry-sdk==" \
      opentelemetry-lambda/python/src/otel/otel_sdk/requirements.txt \
      | cut -d= -f3)
    INSTRUMENTATION_VERSION=$(grep "^opentelemetry-distro==" \
      opentelemetry-lambda/python/src/otel/otel_sdk/requirements.txt \
      | cut -d= -f3)
    if [[ -z "${SDK_VERSION}" ]]; then
      echo "ERROR: could not extract opentelemetry-sdk version from requirements.txt" >&2
      exit 1
    fi
    if [[ -z "${INSTRUMENTATION_VERSION}" ]]; then
      echo "ERROR: could not extract opentelemetry-distro version from requirements.txt" >&2
      exit 1
    fi
    ;;
  nodejs)
    # Extract version from the resolved field which is stable across npm lock formats
    SDK_VERSION=v$(grep -A5 '"node_modules/@opentelemetry/sdk-trace-node"' \
      opentelemetry-lambda/nodejs/package-lock.json \
      | grep '"version"' | grep -o '[0-9][0-9.]*' | head -1)
    if [[ "${SDK_VERSION}" == "v" ]]; then
      echo "ERROR: could not extract @opentelemetry/sdk-trace-node version from package-lock.json" >&2
      exit 1
    fi
    ;;
  java)
    SDK_VERSION=$(grep 'opentelemetry-javaagent:' \
      opentelemetry-lambda/java/dependencyManagement/build.gradle.kts \
      | grep -o '[0-9][0-9.]*' | head -1)
    if [[ -z "${SDK_VERSION}" ]]; then
      echo "ERROR: could not extract opentelemetry-javaagent version from build.gradle.kts" >&2
      exit 1
    fi
    ;;
esac

# --- Update root README.md ---

sed -i.bak \
  "s|release-${LANGUAGE}-v[0-9][0-9.]*/${LANGUAGE}|release-${LANGUAGE}-v${VERSION}/${LANGUAGE}|g" \
  README.md

case "${LANGUAGE}" in
  python)
    sed -i.bak "/Python layer/s|SDK \`v[^\`]*\`|SDK \`v${SDK_VERSION}\`|" README.md
    sed -i.bak "/Python layer/s|instrumentation \`v[^\`]*\`|instrumentation \`v${INSTRUMENTATION_VERSION}\`|" README.md
    sed -i.bak "/Python layer/s|Collector \`v[^\`]*\`|Collector \`${COLLECTOR_VERSION}\`|" README.md
    ;;
  nodejs)
    sed -i.bak "/NodeJS layer/s|SDK \`v[^\`]*\`|SDK \`${SDK_VERSION}\`|" README.md
    sed -i.bak "/NodeJS layer/s|Collector \`v[^\`]*\`|Collector \`${COLLECTOR_VERSION}\`|" README.md
    ;;
  java)
    sed -i.bak "/Java wrapper/s|Java \`v[^\`]*\`|Java \`v${SDK_VERSION}\`|" README.md
    sed -i.bak "/Java wrapper/s|Collector \`v[^\`]*\`|Collector \`${COLLECTOR_VERSION}\`|" README.md
    ;;
esac

echo "Release preparation complete for ${TAG}"
