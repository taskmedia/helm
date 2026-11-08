# Switch /packages/current to the validated revision, then restart Gateway and
# Worker so they load it.
set -eu

PK=/packages
[ -f /state/pending ] || { echo "no change"; exit 0; }
sha="$(cat /state/pending)"
had_revision=false
[ -f "$PK/.revision" ] && had_revision=true

ln -sfn "rev-$sha" "$PK/.current.tmp"
mv -T "$PK/.current.tmp" "$PK/current"
printf '%s\n' "$sha" >"$PK/.revision"
rm -rf "$PK/.lock"
echo "activated $sha"

# newest first; the active revision is the newest
ls -dt "$PK"/rev-* | tail -n +"$((KEEP_REVISIONS + 2))" | xargs -r rm -rf

# On the first sync Gateway and Worker are still waiting for the packages.
if [ "$had_revision" = true ]; then
  for d in $DEPLOYMENTS; do
    kubectl --namespace "$NAMESPACE" rollout restart "deployment/$d"
  done
fi
