# Resolve the ref of every source in /scripts/sources.json to a commit. If the
# set of commits differs from the active revision, check every source out (Git
# LFS included), merge the packages into /packages/rev-<id> and leave the id in
# /packages/.pending for the validate and activate steps. Never touches the
# active revision. Any failure (a ref that does not resolve, a pinned commit
# that differs, a package name that two sources provide) stops here.
set -eu

PK=/packages
SOURCES=/scripts/sources.json
rm -f "$PK/.pending"

apk add --no-cache git-lfs openssh-client >/dev/null

count="$(jq length "$SOURCES")"
field() { jq -r ".[$1].$2" "$SOURCES"; }

# Sets GIT_SSH_COMMAND for the key of source $1, or clears it.
use_key() {
  unset GIT_SSH_COMMAND || true
  dir="/ssh/$1"
  [ -f "$dir/ssh-privatekey" ] || return 0
  install -m 600 "$dir/ssh-privatekey" "/tmp/id-$1"
  check=accept-new
  if [ -f "$dir/known_hosts" ]; then
    cp "$dir/known_hosts" "/tmp/known_hosts-$1"
    check=yes
  fi
  export GIT_SSH_COMMAND="ssh -i /tmp/id-$1 -o IdentitiesOnly=yes -o StrictHostKeyChecking=$check -o UserKnownHostsFile=/tmp/known_hosts-$1"
}

# --- resolve every ref -------------------------------------------------
resolved=""
i=0
while [ "$i" -lt "$count" ]; do
  name="$(field "$i" name)"
  url="$(field "$i" url)"
  ref="$(field "$i" ref)"
  commit="$(field "$i" commit)"
  use_key "$name"

  if printf '%s' "$ref" | grep -Eq '^[0-9a-f]{40}$'; then
    sha="$ref"
  else
    sha=""
    for candidate in "refs/tags/$ref^{}" "refs/tags/$ref" "refs/heads/$ref"; do
      sha="$(git ls-remote "$url" "$candidate" | awk 'NR==1 {print $1}')"
      [ -n "$sha" ] && break
    done
  fi
  if [ -z "$sha" ]; then
    echo "$name: cannot resolve ref '$ref' in $url" >&2
    exit 1
  fi
  echo "$name: ref '$ref' resolves to $sha"

  if [ -n "$commit" ]; then
    case "$sha" in
      "$commit"*) ;;
      *) echo "$name: ref resolves to $sha, packages commit expects $commit: keeping the active revision" >&2; exit 1 ;;
    esac
  fi
  resolved="$resolved$name=$sha
"
  i=$((i + 1))
done

# One source: the commit is the id. Several: a hash over all name=commit pairs.
if [ "$count" -eq 1 ]; then
  id="${resolved#*=}"
  id="${id%?}"
else
  id="$(printf '%s' "$resolved" | sha256sum | cut -c1-16)"
fi

if [ "$id" = "$(cat "$PK/.revision" 2>/dev/null || true)" ] && [ -d "$PK/current/templates" ]; then
  echo "revision $id is already active"
  exit 0
fi

# --- check out and merge -----------------------------------------------
rev="$PK/rev-$id"
rm -rf "$PK/.work" "$rev"
mkdir -p "$PK/.work" "$rev/templates" "$rev/configurations"
: >"$PK/.work/owners"

i=0
while [ "$i" -lt "$count" ]; do
  name="$(field "$i" name)"
  url="$(field "$i" url)"
  path="$(field "$i" path)"
  sha="$(printf '%s' "$resolved" | sed -n "$((i + 1))p" | cut -d= -f2)"
  use_key "$name"

  mkdir "$PK/.work/$name"
  (
    cd "$PK/.work/$name"
    git init -q .
    git remote add origin "$url"
    git lfs install --local >/dev/null
    git fetch -q --depth 1 origin "$sha"
    git checkout -q FETCH_HEAD
    git lfs pull
  )

  src="$PK/.work/$name${path:+/$path}"
  found=false
  for kind in templates configurations; do
    [ -d "$src/$kind" ] || continue
    for pkg in "$src/$kind"/*/; do
      [ -d "$pkg" ] || continue
      found=true
      pkgname="$(basename "$pkg")"
      if [ -e "$rev/$kind/$pkgname" ]; then
        owner="$(grep "^$kind/$pkgname " "$PK/.work/owners" | cut -d' ' -f2)"
        echo "$kind/$pkgname is provided by the sources '$owner' and '$name'; package names must be unique" >&2
        exit 1
      fi
      cp -R "$pkg" "$rev/$kind/$pkgname"
      echo "$kind/$pkgname $name" >>"$PK/.work/owners"
    done
  done
  if [ "$found" = false ]; then
    echo "$name: no package found in $src: set the path of the source to the folder with templates/ and/or configurations/" >&2
    exit 1
  fi
  i=$((i + 1))
done

printf '%s' "$resolved" >"$rev/.sources"
rm -rf "$PK/.work"
chmod -R a+rX "$rev"
printf '%s\n' "$id" >"$PK/.pending"
chmod a+r "$PK/.pending"
