#!/bin/sh
# Install AI/ML API agent skills on macOS or Linux without Node.js:
#
#   curl -fsSL https://aimlapi.com/skills/install.sh | sh
#   curl -fsSL https://aimlapi.com/skills/install.sh | sh -s -- --agent cursor --scope user
#   curl -fsSL https://aimlapi.com/skills/install.sh | sh -s -- aimlapi-models aimlapi-chat
#
# The skills come from the public npm package @aimlapi/skills (the same files
# `npx @aimlapi/skills install` copies). The tarball is checked against the
# registry's sha512 integrity before anything is written. No sudo, no Node.js.
#
# Options (after `sh -s --`):
#   --agent NAME   claude (default), cursor, codex, gemini, opencode, copilot,
#                  universal; repeat or comma-separate for several
#   --scope SCOPE  project (the current repository, default) or user
#   --dir PATH     install into this folder instead
#   --dry-run      show what would be written
#   SKILL ...      only these skills (default: all)
#
# Environment:
#   AIMLAPI_SKILLS_VERSION  version to install, e.g. 1.0.0 (default: latest)
#   AIMLAPI_NPM_REGISTRY    npm registry (default: https://registry.npmjs.org)
#
# Source of truth: install/install.sh in aimlapi/skills, attached to each
# release. The whole script is one function called on the last line, so a
# truncated download (curl | sh) runs nothing.

aimlapi_skills_install() {
	say() {
		printf '%s\n' "$*" >&2
	}

	die() {
		say "aimlapi-skills: error: $*"
		exit 1
	}

	have() {
		command -v "$1" >/dev/null 2>&1
	}

	usage() {
		cat <<'USAGE'
Install AI/ML API agent skills (no Node.js needed).

  curl -fsSL https://aimlapi.com/skills/install.sh | sh -s -- [options] [skill ...]

Options:
  --agent NAME   claude (default), cursor, codex, gemini, opencode, copilot,
                 universal; repeat or comma-separate for several
  --scope SCOPE  project (the current repository, default) or user
  --dir PATH     install into this folder instead
  --dry-run      show what would be written
  skill ...      only these skills (default: all)

Environment:
  AIMLAPI_SKILLS_VERSION  version to install, e.g. 1.0.0 (default: latest)
  AIMLAPI_NPM_REGISTRY    npm registry (default: https://registry.npmjs.org)
USAGE
	}

	cleanup() {
		if [ -n "${SKILLS_TMP-}" ]; then
			rm -rf "$SKILLS_TMP"
		fi
	}

	# fetch URL FILE: download URL to FILE with curl, or wget without curl.
	fetch() {
		if have curl; then
			curl -fsSL --retry 3 --connect-timeout 20 -o "$2" "$1"
		elif have wget; then
			wget -q -T 60 -O "$2" "$1"
		else
			die "neither curl nor wget is installed; install one of them and run this again"
		fi
	}

	# json_get JSON PATH: the string value at PATH ("version", "dist.tarball")
	# of a JSON document, or nothing. Tracks strings, nesting and the key path,
	# so only the top-level field counts, never a same-named key elsewhere.
	json_get() {
		printf '%s\n' "$1" | awk -v want="$2" '
			{ doc = doc $0 }
			END {
				n = length(doc); depth = 0; instr = 0; esc = 0
				for (i = 1; i <= n; i++) {
					c = substr(doc, i, 1)
					if (instr) {
						if (esc) { buf = buf (c == "/" ? "/" : "\\" c); esc = 0; continue }
						if (c == "\\") { esc = 1; continue }
						if (c != "\"") { buf = buf c; continue }
						instr = 0
						if (type[depth] != "o") { continue }
						if (!haskey[depth]) { key[depth] = buf; haskey[depth] = 1; continue }
						path = ""
						for (j = 1; j <= depth; j++) {
							if (type[j] != "o") { path = ""; break }
							path = path (j > 1 ? "." : "") key[j]
						}
						if (path == want) { print buf; exit }
						haskey[depth] = 0
						continue
					}
					if (c == "\"") { instr = 1; buf = ""; continue }
					if (c == "{" || c == "[") { depth++; type[depth] = (c == "{" ? "o" : "a"); haskey[depth] = 0; continue }
					if (c == "}" || c == "]") { depth--; if (depth > 0) { haskey[depth] = 0 }; continue }
					if (c == ",") { haskey[depth] = 0 }
				}
			}'
	}

	# sha512_matches FILE BASE64: whether FILE's sha512 is BASE64 (the digest
	# part of an npm "sha512-<base64>" integrity).
	sha512_matches() {
		if have openssl; then
			actual=$(openssl dgst -sha512 -binary "$1" | openssl base64 -A) || return 1
			[ "$actual" = "$2" ]
			return
		fi

		if have sha512sum; then
			actual=$(sha512sum "$1" | cut -d ' ' -f 1)
		elif have shasum; then
			actual=$(shasum -a 512 "$1" | cut -d ' ' -f 1)
		else
			die "cannot verify the download: install openssl, sha512sum or shasum"
		fi

		expected=
		for flag in -d -D; do
			expected=$(printf '%s' "$2" | base64 "$flag" 2>/dev/null | od -A n -v -t x1 | tr -d ' \n')
			if [ -n "$expected" ]; then
				break
			fi
		done
		if [ -z "$expected" ]; then
			die "cannot verify the download: base64 cannot decode the registry's integrity"
		fi

		[ "$actual" = "$expected" ]
	}

	# agent_dir AGENT SCOPE: the folder AGENT reads skills from, relative to
	# the repository root (project) or the home folder (user). The same places
	# `gh skill install` and `npx @aimlapi/skills` use.
	agent_dir() {
		case $1:$2 in
		claude:*) echo .claude/skills ;;
		cursor:project | codex:project | gemini:project | opencode:project | copilot:project | universal:*) echo .agents/skills ;;
		cursor:user) echo .cursor/skills ;;
		codex:user) echo .codex/skills ;;
		gemini:user) echo .gemini/skills ;;
		opencode:user) echo .config/opencode/skills ;;
		copilot:user) echo .copilot/skills ;;
		*) return 1 ;;
		esac
	}

	project_root() {
		if have git && root=$(git rev-parse --show-toplevel 2>/dev/null) && [ -n "$root" ]; then
			echo "$root"
			return
		fi
		pwd
	}

	# ---- main

	set -u
	umask 022

	agents=
	scope=project
	dir=
	dry_run=
	skills=
	while [ $# -gt 0 ]; do
		case $1 in
		--agent)
			[ $# -ge 2 ] || die "--agent needs a value"
			agents="$agents $(printf '%s' "$2" | tr ',' ' ')"
			shift 2
			;;
		--agent=*)
			agents="$agents $(printf '%s' "${1#--agent=}" | tr ',' ' ')"
			shift
			;;
		--scope)
			[ $# -ge 2 ] || die "--scope needs a value"
			scope=$2
			shift 2
			;;
		--scope=*)
			scope=${1#--scope=}
			shift
			;;
		--dir)
			[ $# -ge 2 ] || die "--dir needs a value"
			dir=$2
			shift 2
			;;
		--dir=*)
			dir=${1#--dir=}
			shift
			;;
		--dry-run)
			dry_run=1
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		-*) die "unknown option $1 (see --help)" ;;
		*)
			case $1 in
			aimlapi-*) ;;
			*) die "unknown skill $1 (skill names start with aimlapi-)" ;;
			esac
			case $1 in
			*[!a-z0-9-]*) die "invalid skill name $1" ;;
			esac
			skills="$skills $1"
			shift
			;;
		esac
	done

	case $scope in
	project | user) ;;
	*) die "--scope must be project or user, not $scope" ;;
	esac
	if [ -z "$agents" ]; then
		agents=claude
	fi
	for agent in $agents; do
		agent_dir "$agent" "$scope" >/dev/null || die "unknown agent $agent; use claude, cursor, codex, gemini, opencode, copilot or universal"
	done

	if [ -n "$dir" ]; then
		case $dir in
		/*) targets=$dir ;;
		*) targets=$(pwd)/$dir ;;
		esac
	else
		if [ "$scope" = user ]; then
			[ -n "${HOME-}" ] || die "HOME is not set; use --dir"
			base=$HOME
		else
			base=$(project_root)
		fi
		targets=
		for agent in $agents; do
			t=$base/$(agent_dir "$agent" "$scope")
			case " $targets " in
			*" $t "*) ;;
			*) targets="$targets $t" ;;
			esac
		done
	fi

	registry=${AIMLAPI_NPM_REGISTRY:-https://registry.npmjs.org}
	registry=${registry%/}
	version=${AIMLAPI_SKILLS_VERSION:-latest}
	version=${version#v}
	case $version in
	'' | *[!0-9A-Za-z.+-]*) die "invalid AIMLAPI_SKILLS_VERSION: ${AIMLAPI_SKILLS_VERSION-}" ;;
	esac
	metadata_url="$registry/@aimlapi%2fskills/$version"

	SKILLS_TMP=$(mktemp -d 2>/dev/null || mktemp -d -t aimlapi-skills) || die "cannot create a temporary directory"
	trap cleanup EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM
	trap 'exit 129' HUP

	say "Fetching @aimlapi/skills@$version from $registry"
	fetch "$metadata_url" "$SKILLS_TMP/metadata.json" ||
		die "cannot fetch $metadata_url (no such version, or the registry is unreachable)"
	metadata=$(tr -d '\r\n' <"$SKILLS_TMP/metadata.json")

	resolved=$(json_get "$metadata" version)
	tarball=$(json_get "$metadata" dist.tarball)
	integrity=$(json_get "$metadata" dist.integrity)
	if [ -z "$resolved" ] || [ -z "$tarball" ]; then
		die "unexpected registry response from $metadata_url"
	fi
	case $version in
	[0-9]*)
		[ "$resolved" = "$version" ] || die "the registry returned version $resolved for $version"
		;;
	esac
	case $tarball in
	https://* | http://*) ;;
	*) die "unexpected tarball URL in the registry response: $tarball" ;;
	esac

	sha512=
	for hash in $integrity; do
		case $hash in
		sha512-*)
			sha512=${hash#sha512-}
			break
			;;
		esac
	done
	[ -n "$sha512" ] || die "the registry gave no sha512 integrity for @aimlapi/skills@$resolved; refusing to install"

	fetch "$tarball" "$SKILLS_TMP/package.tgz" || die "cannot download $tarball"
	sha512_matches "$SKILLS_TMP/package.tgz" "$sha512" ||
		die "integrity check failed for $tarball: its sha512 does not match the registry's; refusing to install"

	(cd "$SKILLS_TMP" && tar -xzf package.tgz package/skills) 2>/dev/null ||
		die "cannot extract the skills from $tarball"
	src=$SKILLS_TMP/package/skills

	if [ -z "$skills" ]; then
		for d in "$src"/*/; do
			name=$(basename "$d")
			if [ -f "$src/$name/SKILL.md" ]; then
				skills="$skills $name"
			fi
		done
	fi
	for name in $skills; do
		[ -f "$src/$name/SKILL.md" ] || die "@aimlapi/skills@$resolved has no skill $name"
	done

	for target in $targets; do
		for name in $skills; do
			dest=$target/$name
			if [ -e "$dest" ]; then
				verb=update
			else
				verb=install
			fi
			if [ -n "$dry_run" ]; then
				say "would $verb $dest"
				continue
			fi
			mkdir -p "$target" || die "cannot create $target"
			# Copy next to the destination, then swap, so a failed copy never leaves half a skill.
			staged=$target/.$name.install.$$
			rm -rf "$staged"
			cp -R "$src/$name" "$staged" || die "cannot write to $target"
			rm -rf "$dest"
			mv "$staged" "$dest" || die "cannot move $name into $target"
			say "${verb}d $dest"
		done
	done

	if [ -z "$dry_run" ]; then
		say ""
		say "@aimlapi/skills $resolved is in place. Restart your agent (or start a new session) so it loads the skills."
		say "Scripts and examples read your key from AIMLAPI_API_KEY."
	fi
}

aimlapi_skills_install "$@"
