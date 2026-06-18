#!/bin/bash

set -euo pipefail

: "${TAG:?TAG is required (e.g. python-v1.41.0)}"
: "${LANGUAGE:?LANGUAGE is required (java, nodejs, or python)}"
: "${VERSION:?VERSION is required (e.g. 1.41.0)}"

README="${LANGUAGE}/README.md"

gh api "repos/${GITHUB_REPOSITORY}/releases/tags/${TAG}" \
  --jq '.body' > /tmp/release_body.md

python3 - "${README}" "${TAG}" "${VERSION}" /tmp/release_body.md <<'PYEOF'
import re
import sys

readme_path = sys.argv[1]
tag = sys.argv[2]
version = sys.argv[3]
release_body_path = sys.argv[4]

with open(release_body_path) as f:
    body = f.read()

def extract_table(text, heading_fragment):
    lines = text.splitlines()
    capture = False
    table_lines = []
    for line in lines:
        if heading_fragment.lower() in line.lower():
            capture = True
            continue
        if capture:
            if line.startswith("##"):
                break
            if line.strip():
                table_lines.append(line)
    return "\n".join(table_lines)

amd64_table = extract_table(body, "AMD64 Lambda Layers List")
arm64_table = extract_table(body, "ARM64 Lambda Layers List")

if not amd64_table:
    print("ERROR: Could not extract AMD64 table from pre-release body",
          file=sys.stderr)
    sys.exit(1)
if not arm64_table:
    print("ERROR: Could not extract ARM64 table from pre-release body",
          file=sys.stderr)
    sys.exit(1)

with open(readme_path) as f:
    content = f.read()

if "unreleased version" not in content:
    print(f"ERROR: 'unreleased version' not found in {readme_path}",
          file=sys.stderr)
    sys.exit(1)

content = re.sub(
    r"unreleased version",
    f"v{version}",
    content,
    count=1,
)

def replace_section(text, heading, new_table):
    lines = text.splitlines()
    result = []
    skip = False
    found = False
    for line in lines:
        if line.strip().startswith("##") and heading.lower() in line.lower():
            found = True
            result.append(line)
            result.append("")
            result.append(new_table)
            result.append("")
            skip = True
            continue
        if skip:
            if line.strip().startswith("##"):
                skip = False
                result.append(line)
            continue
        result.append(line)
    if not found:
        print(f"ERROR: heading '{heading}' not found in {readme_path}",
              file=sys.stderr)
        sys.exit(1)
    return "\n".join(result)

content = replace_section(content, "AMD64 Lambda Layers List", amd64_table)
content = replace_section(content, "ARM64 Lambda Layers List", arm64_table)

content = re.sub(
    r"releases/download/[^/]+/",
    f"releases/download/{tag}/",
    content,
)

if not content.endswith("\n"):
    content += "\n"

with open(readme_path, "w") as f:
    f.write(content)

print(f"Updated {readme_path} with ARN tables for {tag}")
PYEOF
