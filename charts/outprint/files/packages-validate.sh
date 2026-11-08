# Check the pending revision with the same code the Gateway runs at start-up.
# With a service configuration the roots come from the environment.
set -eu

[ -f /state/pending ] || { echo "nothing to validate"; exit 0; }
sha="$(cat /state/pending)"
export OUTPRINT_TEMPLATES_ROOT="/packages/rev-$sha/templates"
export OUTPRINT_CONFIGURATIONS_ROOT="/packages/rev-$sha/configurations"
exec outprint validate --service-config /etc/outprint/service.yaml
