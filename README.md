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

| Chart | Version | Description | Released |
|------|---------|-------------|----------|
| ipsec-vpn-server | [2.2.1](https://github.com/taskmedia/helm/releases/download/ipsec-vpn-server-2.2.1/ipsec-vpn-server-2.2.1.tgz) | Deploy IPsec VPN server inside K8s with optional sealed-secrets | 2026-10-11 |
| paperless-gpt | [0.1.0](https://github.com/taskmedia/helm/releases/download/paperless-gpt-0.1.0/paperless-gpt-0.1.0.tgz) | A Helm chart for paperless-gpt, an LLM-powered OCR and metadata assistant for paperless-ngx | 2026-10-11 |
| paperless-ngx-backup | [1.1.2](https://github.com/taskmedia/helm/releases/download/paperless-ngx-backup-1.1.2/paperless-ngx-backup-1.1.2.tgz) | Backup paperless-ngx via K8s cronjob to FTP | 2026-10-11 |
| paperless-ngx-ftp-bridge | [0.1.3](https://helm.task.media/paperlessngx-ftp-bridge/paperless-ngx-ftp-bridge-0.1.3.tgz) | A Helm chart to upload files to from a FTP (TLS) server to paperless-ngx | 2024-10-29 |
| paperlessngx-ftp-bridge | [2.0.2](https://github.com/taskmedia/helm/releases/download/paperlessngx-ftp-bridge-2.0.2/paperlessngx-ftp-bridge-2.0.2.tgz) | A Helm chart for an embedded FTP/FTPS server that forwards uploaded files to paperless-ngx | 2026-10-11 |
| vpn-ios-profile | [0.3.2](https://github.com/taskmedia/helm/releases/download/vpn-ios-profile-0.3.2/vpn-ios-profile-0.3.2.tgz) | Deploy a VPN server in K8s with provided iOS profile | 2026-10-11 |

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
