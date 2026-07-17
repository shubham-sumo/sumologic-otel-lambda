# Releasing guide

Release preparation and publication are automated with GitHub Actions. Java,
NodeJS, and Python preparation pull requests may be open at the same time.

## Release metadata

Each language has a `<language>/version.txt` file with named values:

```text
current_version=1.41.0
upstream_release_tag=layer-python/0.20.0
```

- `current_version` is the latest Sumo Logic release for that language.
- `upstream_release_tag` is the upstream OpenTelemetry Lambda release detected
  for that language.

The upstream tag prefixes are:

- Java: `layer-javaagent/`
- NodeJS: `layer-nodejs/`
- Python: `layer-python/`

Submodule pinning is not part of this automation yet. The selected upstream tag
is recorded as release metadata, but the prepare workflow does not change the
`opentelemetry-lambda` gitlink.

## Prepare a release

The `Check Upstream Releases` workflow runs weekly and can also be dispatched
manually. It compares the latest language-specific upstream tag with
`upstream_release_tag` and dispatches `Release Prepare` when it finds a newer
release.

`Release Prepare` can also be dispatched directly with:

- `language`: `java`, `nodejs`, or `python`
- `version`: the next release version without a `v` prefix
- `otel_lambda_tag`: the matching language-specific upstream tag

The workflow opens `prepare-<language>-v<version>` with these changes:

- `changelog/<language>-v<version>.md`
- `<language>/version.txt`
- `<language>/layer-data.sh`
- `<language>/sample-apps/template.yaml`
- `<language>/README.md`
- root `README.md`

The changelog fragment prevents concurrent release preparations from editing
`CHANGELOG.md`. Before merging the pull request:

1. Replace the fragment's TODO with the release changes.
2. Verify the named values in `<language>/version.txt`.
3. Verify the layer version in `<language>/layer-data.sh`.
4. Verify the layer version in `<language>/sample-apps/template.yaml`.
5. Verify the version in the title of `<language>/README.md`.
6. Verify the root README release link and component versions.
7. Resolve any normal pull-request conflict, including a shared root README
   conflict caused by another release merged on the same day.

Only one open prepare pull request is allowed per language. An open Java
prepare pull request does not block NodeJS or Python preparation.

## Automatic post-merge flow

Merging a prepare pull request triggers the following sequence:

1. `Release Tag` serializes changes to `main` across all languages.
2. It inserts `changelog/<language>-v<version>.md` at the top of
   `CHANGELOG.md` and deletes the fragment.
3. It commits the assembled changelog and creates
   `<language>-v<version>` at that commit.
4. It pushes the release tag. Because this push uses `GITHUB_TOKEN`, it does
   not automatically start the unchanged tag-push-only release-build workflow.
5. Start the existing release-build workflow through the repository's current
   release procedure. It creates artifacts, publishes Lambda layers, and
   creates a GitHub pre-release containing the ARN tables and release artifacts.
6. Review the pre-release. The GitHub release remains a pre-release.
7. When ready to publish, open the pre-release on the GitHub Releases page,
   edit it, clear the pre-release setting, mark it as the latest release, and
   publish it.

Final promotion is a manual GitHub UI step.

## Recovery

- If preparation fails, correct the input or workflow issue and dispatch
  `Release Prepare` again.
- If changelog assembly fails, restore or correct the expected fragment or the
  `All notable changes` anchor before rerunning the merge-triggered workflow.
- If a tag exists but its build did not start, use the repository's current
  release procedure to start the existing tag-push-only build workflow.

Do not promote the pre-release before its contents have been reviewed.
