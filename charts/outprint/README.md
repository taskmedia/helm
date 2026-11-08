# outprint

Helm chart for [Outprint](https://github.com/taskmedia/outprint), PDF export for a self-hosted
[Outline](https://www.getoutline.com/). It runs the Gateway, the network-less Worker and, optionally,
the injector for Outline's Export menu. Images: `ghcr.io/taskmedia/outprint` and
`ghcr.io/taskmedia/outprint-injector`; the tag defaults to the chart's `appVersion`.

Documentation (concepts, the Worker security baseline, scaling, routing):
[Helm and Kubernetes](https://github.com/taskmedia/outprint/blob/main/docs/deploy/helm-kubernetes.md).

## Usage

```bash
helm repo add taskmedia https://helm.task.media
helm install outprint taskmedia/outprint \
  --namespace outprint --create-namespace \
  --set outline.url=http://outline.outline.svc:3000
```

Then route your edge proxy to the Service `outprint-injector` instead of Outline. Do not expose the
Gateway or the Worker. For PDF by link only, set `injector.enabled=false`.

## Values

See [values.yaml](values.yaml); every option is commented. `outline.url` is required.

## IngressRoute

As an alternative to `injector.ingress`, the chart can render a Traefik `IngressRoute` (CRD) that
sends the whole host to the injector. The injector forwards `/pdf/*` to the Gateway and everything
else to Outline, so no prefix middleware is needed. Move the host off Outline's own Ingress first;
two routers must not claim it. cert-manager's ingress-shim does not handle `IngressRoute`, so the
chart can also create the `Certificate`:

```yaml
outline:
  url: http://outline.outline.svc:3000
ingressRoute:
  enabled: true
  host: wiki.example.com
  tls:
    secretName: outprint-tls
    certificate:
      enabled: true
      issuerRef:
        name: letsencrypt-prod
```

Needs `injector.enabled` and the Traefik (and, for the certificate, cert-manager) CRDs in the cluster.

## Your own Templates and Configurations

The chart ships `neutral` and `example` in the image. To use your own packages, set one source under
`packages` (documentation: Install > Run Outprint > Your own Templates and Configurations):

```yaml
packages:
  git:
    url: git@github.com:example/letters.git
    ref: v1.0.0                       # tag, branch or commit
    path: outprint                    # folder with templates/ and configurations/
    sshKeySecret: letters-deploy-key  # key `ssh-privatekey`, optional `known_hosts`
serviceConfig:
  bindings:
    - template: letter
      configuration: acme
  defaultBinding:
    template: letter
    configuration: acme
```

With `git`, a Job (at install and on a change of a source) and a CronJob (every `packages.git.interval`)
resolve each `ref` to a commit. On a change they clone the commits (Git LFS included), run
`outprint validate` against the service configuration and switch over only if it passes; then they restart
Gateway and Worker. A broken revision never replaces a working one. `commit` refuses any other commit.

For packages from more than one repository, list them under `packages.sources` (the shorthand
`packages.git` counts as a source named `default`):

```yaml
packages:
  sources:
    - name: letters
      git: {url: git@github.com:example/letters.git, ref: v1.0.0, path: outprint, sshKeySecret: letters-key}
    - name: reports
      git: {url: https://github.com/example/reports.git, ref: main}
```

Each source brings `templates/<name>` and/or `configurations/<name>`. The packages of all sources are merged
into one revision that is validated and switched as a whole; a package name that two sources provide stops
the sync and keeps the running revision. `interval`, `image`, `resources`, `persistence` and `keepRevisions`
under `packages.git` apply to all sources. Only the Job has network access; the Worker keeps its NetworkPolicy. The revisions live on a
`ReadWriteOnce` PVC, so on a multi-node cluster pin Gateway, Worker and the Job to one node or use a
ReadWriteMany storage class. When a change adds a Binding that the running revision does not have yet, the
Gateway and the Worker restart until the Job has switched over.

`packages.image` mounts an OCI image as a Kubernetes image volume (Kubernetes 1.35+ or the `ImageVolume`
feature gate); `packages.existingClaim` mounts a PVC you maintain. `gateway.extraVolumes` /
`gateway.extraVolumeMounts` (and the same under `worker`) cover everything else.
