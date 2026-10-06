# taskmedia/helm

[![GitHub Repo](https://img.shields.io/badge/GitHub-taskmedia%2Fhelm-181717?logo=github)](https://github.com/taskmedia/helm)
[![Release Charts](https://github.com/taskmedia/helm/actions/workflows/release.yaml/badge.svg)](https://github.com/taskmedia/helm/actions/workflows/release.yaml)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/taskmedia)](https://artifacthub.io/packages/search?repo=taskmedia)

Source repository for [task.media](https://task.media)'s Helm charts. Charts here are packaged
and published by [chart-releaser](https://github.com/helm/chart-releaser) to the Helm repository
hosted at **[helm.task.media](https://helm.task.media)**, and mirrored as OCI artifacts to
[ghcr.io/taskmedia](https://github.com/orgs/taskmedia/packages?tab=packages&q=helm).

## Usage

Add the repository and install a chart:

```bash
helm repo add taskmedia https://helm.task.media
helm repo update
helm install my-release taskmedia/<chart>
```

Or install directly via OCI:

```bash
helm upgrade --install my-release oci://ghcr.io/taskmedia/<chart>
```

## Charts

For published versions and release dates, see [helm.task.media](https://helm.task.media)
or [Artifact Hub](https://artifacthub.io/packages/search?repo=taskmedia). The table below tracks
chart sources on `main`; the release workflow replaces it with a live version table when this
README is mirrored to `gh-pages`.

<!-- start charts -->

| Chart | Description | Source |
|-------|-------------|--------|
| [ipsec-vpn-server](charts/ipsec-vpn-server) | Deploy IPsec VPN server inside K8s with optional sealed-secrets | [taskmedia/helm](https://github.com/taskmedia/helm/tree/main/charts/ipsec-vpn-server) |
| [paperlessngx-backup](charts/paperlessngx-backup) | Backup paperless-ngx via K8s cronjob to FTP | [taskmedia/helm](https://github.com/taskmedia/helm/tree/main/charts/paperlessngx-backup) |
| [paperlessngx-ftp-bridge](charts/paperlessngx-ftp-bridge) | Upload files from a FTP (TLS) server to paperless-ngx | [taskmedia/helm](https://github.com/taskmedia/helm/tree/main/charts/paperlessngx-ftp-bridge) |
| [vpn-ios-profile](charts/vpn-ios-profile) | Deploy a VPN server in K8s with a provided iOS profile | [taskmedia/helm](https://github.com/taskmedia/helm/tree/main/charts/vpn-ios-profile) |

<!-- end charts -->

## Repository layout

```
charts/      Helm chart sources, one directory per chart
scripts/     Local helper scripts (sealed-secrets, public key fetch)
```

Each chart's source previously lived in its own `taskmedia/helm_<chart>` repository; those
repositories have been merged into this one, which now packages, releases, and sources each chart.

## Releasing

Pushing a change under `charts/**` to `main` triggers `.github/workflows/release.yaml`, which runs
chart-releaser to cut a GitHub release per changed chart and update the chart table on `gh-pages`
(the branch served at helm.task.media).
