# Resolve GIT_REF to a commit and, if it differs from the active one, check it
# out (Git LFS included) as /packages/rev-<commit>. Leaves /packages/.pending
# for the validate and activate steps. Never touches the active revision.
set -eu

PK=/packages
rm -f "$PK/.pending"

apk add --no-cache git-lfs openssh-client >/dev/null

if [ -f /ssh/ssh-privatekey ]; then
  install -m 600 /ssh/ssh-privatekey /tmp/id
  check=accept-new
  if [ -f /ssh/known_hosts ]; then
    cp /ssh/known_hosts /tmp/known_hosts
    check=yes
  fi
  export GIT_SSH_COMMAND="ssh -i /tmp/id -o IdentitiesOnly=yes -o StrictHostKeyChecking=$check -o UserKnownHostsFile=/tmp/known_hosts"
fi

if printf '%s' "$GIT_REF" | grep -Eq '^[0-9a-f]{40}$'; then
  sha="$GIT_REF"
else
  sha=""
  for candidate in "refs/tags/$GIT_REF^{}" "refs/tags/$GIT_REF" "refs/heads/$GIT_REF"; do
    sha="$(git ls-remote "$GIT_URL" "$candidate" | awk 'NR==1 {print $1}')"
    [ -n "$sha" ] && break
  done
fi
if [ -z "$sha" ]; then
  echo "cannot resolve ref '$GIT_REF' in $GIT_URL" >&2
  exit 1
fi
echo "ref '$GIT_REF' resolves to $sha"

if [ -n "$GIT_COMMIT" ]; then
  case "$sha" in
    "$GIT_COMMIT"*) ;;
    *) echo "ref resolves to $sha, packages.git.commit expects $GIT_COMMIT: keeping the active revision" >&2; exit 1 ;;
  esac
fi

if [ "$sha" = "$(cat "$PK/.revision" 2>/dev/null || true)" ] && [ -d "$PK/current/templates" ]; then
  echo "revision $sha is already active"
  exit 0
fi

rm -rf "$PK/.work" "$PK/rev-$sha"
mkdir "$PK/.work"
cd "$PK/.work"
git init -q .
git remote add origin "$GIT_URL"
git lfs install --local >/dev/null
git fetch -q --depth 1 origin "$sha"
git checkout -q FETCH_HEAD
git lfs pull

src="$PK/.work${PKG_PATH:+/$PKG_PATH}"
for dir in templates configurations; do
  if [ ! -d "$src/$dir" ]; then
    echo "$src/$dir not found: set packages.git.path to the folder with templates/ and configurations/" >&2
    exit 1
  fi
done
mkdir "$PK/rev-$sha"
cp -R "$src/templates" "$src/configurations" "$PK/rev-$sha/"
cd "$PK"
rm -rf "$PK/.work"
chmod -R a+rX "$PK/rev-$sha"
printf '%s\n' "$sha" >"$PK/.pending"
chmod a+r "$PK/.pending"
