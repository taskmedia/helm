# paperless-gpt

Helm chart for [paperless-gpt](https://github.com/icereed/paperless-gpt), an LLM-powered OCR and
metadata assistant for [paperless-ngx](https://docs.paperless-ngx.com/). It uses the official
upstream image `icereed/paperless-gpt`.

> **paperless-gpt has no built-in authentication.** The chart creates a `ClusterIP` service only;
> put an authenticating proxy (e.g. forward-auth) in front of any ingress.

## Usage

```bash
helm repo add taskmedia https://helm.task.media
helm install paperless-gpt taskmedia/paperless-gpt -f values.yaml
```

Minimal values (OpenAI, secrets from an existing secret):

```yaml
paperless:
  baseUrl: http://paperless-ngx:8000
  apiTokenExistingSecret:
    name: paperless-gpt
    key: paperless-api-token

config:
  LLM_PROVIDER: openai
  LLM_MODEL: gpt-4o

# every key of this secret is injected as environment variable (e.g. OPENAI_API_KEY)
existingSecret: paperless-gpt
```

Example with a local [Ollama](https://ollama.com/) instance (no API key needed, so no secret for the LLM):

```yaml
paperless:
  baseUrl: http://paperless-ngx:8000
  apiTokenExistingSecret:
    name: paperless-gpt
    key: paperless-api-token

config:
  # metadata suggestions (title, tags, correspondent, ...)
  LLM_PROVIDER: ollama
  LLM_MODEL: qwen3:8b
  OLLAMA_HOST: http://ollama.ollama.svc.cluster.local:11434
  OLLAMA_CONTEXT_LENGTH: "8192"
  TOKEN_LIMIT: "1000" # recommended for smaller models
  # vision based OCR
  OCR_PROVIDER: llm
  VISION_LLM_PROVIDER: ollama
  VISION_LLM_MODEL: minicpm-v
```

Any upstream [environment variable](https://github.com/icereed/paperless-gpt#configuration) can be
set via `config` (plain), `secretConfig` (stored in a chart-managed secret) or `existingSecret`.

## Notes

- Runs a single replica with the `Recreate` strategy: state is a local SQLite database.
- `persistence` stores `/app/prompts`, `/app/config` and `/app/db` (prompts, UI settings, history).
- Runs as non-root (UID/GID 10001); `PUID`/`PGID` are not used in that mode.
- No health endpoint is documented upstream, so probes check the TCP port.
- Use `extraVolumes`/`extraVolumeMounts` for hOCR/PDF output or Google Document AI credentials.
