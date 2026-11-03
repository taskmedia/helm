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
