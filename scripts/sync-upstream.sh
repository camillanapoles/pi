#!/data/data/com.termux/files/usr/bin/sh
# pi update — fork edition (Termux source build at ~/pi)
#
# This fork's contract: origin (camillanapoles/pi) = upstream (earendil-works/pi)
# + local adaptations. The real "update" for this installation is the git cycle
# plus a bundle rebuild — `pi update`'s built-in self-update can't do either.
#
# Wired in by the /usr/bin/pi wrapper (device-local): bare `pi update` execs
# this script; `pi update --models|--extensions|<source>` stay native.
#
# If the wrapper is ever lost, restore it with:
#   printf '%s\n' '#!/data/data/com.termux/files/usr/bin/bash' \
#     'if [ "$1" = "update" ] && [ $# -eq 1 ]; then' \
#     '  exec sh "$HOME/pi/scripts/sync-upstream.sh" "$@"' 'fi' \
#     'export LD_PRELOAD="/data/data/com.termux/files/usr/lib/libtermux-exec.so"' \
#     'exec node "$HOME/pi/packages/coding-agent/dist/bundle/cli.js" "$@"' \
#     > /data/data/com.termux/files/usr/bin/pi && chmod +x /data/data/com.termux/files/usr/bin/pi
#
# On merge conflict: resolve with fork governance (keep .husky/pre-commit and
# bun.lock as ours; package-lock.json now merges cleanly), then
# `git commit --no-edit` and rerun this script.

set -eu
cd "$(git rev-parse --show-toplevel)"

if [ -n "$(git status --porcelain)" ]; then
	echo "stop: working tree has uncommitted changes - commit or stash them first" >&2
	git status --short >&2
	exit 1
fi

echo "==> fetch upstream"
git fetch upstream

BEHIND=$(git rev-list --count main..upstream/main)
if [ "$BEHIND" = "0" ]; then
	echo "==> upstream: nothing new"
else
	echo "==> merge upstream/main ($BEHIND new commits)"
	git merge upstream/main --no-edit
fi

echo "==> push origin main"
git push origin main

echo "==> rebuild packages/ai/dist"
(
	cd packages/ai
	NODE_OPTIONS="--max-old-space-size=2048" node ../../node_modules/typescript/bin/tsc -p tsconfig.build.json --noCheck
	rm -rf dist/providers/data
	cp -r src/providers/data dist/providers/data
)

echo "==> rebuild bundle"
(
	cd packages/coding-agent
	node ../../scripts/build-coding-agent-bundle.mjs
)

echo "==> verify"
pi --version

echo "done: fork = upstream + adaptations; binary rebuilt from merged source."
