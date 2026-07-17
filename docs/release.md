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
- root `README.md`

The changelog fragment prevents concurrent release preparations from editing
`CHANGELOG.md`. Before merging the pull request:

1. Replace the fragment's TODO with the release changes.
2. Verify the named values in `<language>/version.txt`.
3. Verify the layer version in `<language>/layer-data.sh`.
4. Verify the layer version in `<language>/sample-apps/template.yaml`.
5. Verify the root README release link and component versions.
6. Resolve any normal pull-request conflict, including a shared root README
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
4. It explicitly dispatches the matching language build workflow at the tag.
   The dispatch-capable build workflows must already be present on `main` before
   the first automated release is merged.
5. The build workflow identifies the previous tag for the same language and
   asks GitHub to generate release notes for that tag range. It creates
   artifacts, publishes Lambda layers, and creates a GitHub pre-release with
   those generated notes and the layer ARN tables. The reviewed changelog
   fragment remains the source for the repository `CHANGELOG.md`.
6. A successful build creates and pushes `release-<language>-v<version>`.
   That branch updates the language README title from `unreleased version` (or
   its previous version) to the new version. No pull request is opened for this
   branch.
7. Review the pre-release and the pushed release branch. The GitHub release
   remains a pre-release.
8. When ready to publish, open the pre-release on the GitHub Releases page,
   edit it, clear the pre-release setting, mark it as the latest release, and
   publish it.

Finalization is idempotent: rerunning it does not recreate an existing release
branch. Final promotion is a manual GitHub UI step.

## Recovery

- If preparation fails, correct the input or workflow issue and dispatch
  `Release Prepare` again.
- If changelog assembly fails, restore or correct the expected fragment or the
  `All notable changes` anchor before rerunning the merge-triggered workflow.
- If a tag exists but its build did not start, dispatch the matching
  `release-build-<language>.yml` workflow using the release tag as its ref.
- If release-branch finalization fails, dispatch `release-finalize.yml` with
  the release tag after correcting the failure.

Do not promote the pre-release before the pre-release contents and generated
release branch have been reviewed.
