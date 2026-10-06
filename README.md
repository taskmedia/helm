[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/taskmedia)](https://artifacthub.io/packages/search?repo=taskmedia)

# task.media Helm charts

- [ipsec-vpn-server](./ipsec-vpn-server/) [![GitHub](https://img.shields.io/badge/repository-taskmedia%2Fhelm__ipsec--vpn--server-lightgrey?logo=github&style=flat-square)](https://github.com/taskmedia/helm_ipsec-vpn-server)
- [paperlessngx-backup](./paperlessngx-backup/) [![GitHub](https://img.shields.io/badge/repository-taskmedia%2Fhelm__paperlessngx--backup-lightgrey?logo=github&style=flat-square)](https://github.com/taskmedia/helm_paperlessngx-backup)
- [paperlessngx-ftp-bridge](./paperlessngx-ftp-bridge/) [![GitHub](https://img.shields.io/badge/repository-taskmedia%2Fhelm__paperlessngx--ftp--bridge-lightgrey?logo=github&style=flat-square)](https://github.com/taskmedia/paperlessngx-ftp-bridge)
- [vpn-ios-profile](./vpn-ios-profile/) [![GitHub](https://img.shields.io/badge/repository-taskmedia%2Fhelm__vpn--ios--profile-lightgrey?logo=github&style=flat-square)](https://github.com/taskmedia/helm_vpn-ios-profile)

# Helm OCI installation

Installation also possible via OCI from [ghcr.io](https://ghcr.io/):

```bash
$ helm upgrade --install vpn oci://ghcr.io/taskmedia/ipsec-vpn-server
```

## Charts

<!-- start charts -->
| Chart | Version | Description | Released |
|------|---------|-------------|----------|
| ipsec-vpn-server | [2.2.0](https://helm.task.media/ipsec-vpn-server/ipsec-vpn-server-2.2.0.tgz) | Deploy IPsec VPN server inside K8s with optional sealed-secrets | 2026-09-10 |
| paperless-ngx-backup | [1.1.1](https://github.com/taskmedia/helm/releases/download/paperless-ngx-backup-1.1.1/paperless-ngx-backup-1.1.1.tgz) | Backup paperless-ngx via K8s cronjob to FTP | 2026-10-06 |
| paperless-ngx-ftp-bridge | [0.1.3](https://helm.task.media/paperlessngx-ftp-bridge/paperless-ngx-ftp-bridge-0.1.3.tgz) | A Helm chart to upload files to from a FTP (TLS) server to paperless-ngx | 2024-10-29 |
| paperlessngx-ftp-bridge | [1.3.1](https://helm.task.media/paperlessngx-ftp-bridge/paperlessngx-ftp-bridge-1.3.1.tgz) | A Helm chart to upload files to from a FTP (TLS) server to paperless-ngx | 2026-09-10 |
| vpn-ios-profile | [0.3.1](https://helm.task.media/vpn-ios-profile/vpn-ios-profile-0.3.1.tgz) | Deploy a VPN server in K8s with provided iOS profile | 2026-09-10 |
<!-- end charts -->
