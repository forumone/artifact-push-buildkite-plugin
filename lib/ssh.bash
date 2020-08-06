# ABOUT THIS FILE
#
# This file contains functions related to the SSH configuration and actions.

shopt -s extglob

# Usage:
#   validate-ssh-config
#
# This validation function needs to be called before any SSH-related function is called.
# It returns the number of failures encountered during validation. If non-zero, then it is
# not safe to proceed.
validate-ssh-config() {
  local keyscan=
  keyscan="$(get-config ssh keyscan)"

  # If there's no keyscan option set, then we don't have anything to validate.
  if test -z "$keyscan"; then
    return
  fi

  local failures=0

  local server
  IFS=: read -ra server <<<"$keyscan"

  case "${#server[@]}" in
  1)
    # If we only received the host, then do nothing - we assume any host name is valid.
    ;;

  2)
    # If there are two segments, then the second should be a numeric value. We validate
    # that here.
    local port="${server[1]}"

    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
      error "The port '${port}' should be numeric."
      failures=$((failures + 1))
    fi
    ;;

  *)
    error "The keyscan option '${keyscan}' should be in HOST or HOST:PORT format."
    failures=$((failures + 1))
    ;;
  esac

  [ "$failures" -eq 0 ]
}

# Usage:
#   ssh-keyscan-host
#
# Returns the host for SSH key scanning. This value is empty if there is no keyscan option
# in the configuration. Thus `test -z $keyscan_host` will suffice to determine if there is
# no need for
ssh-keyscan-host() {
  local keyscan
  keyscan="$(get-config ssh keyscan)"

  if test -z "$keyscan"; then
    return
  fi

  local server
  IFS=: read -ra server <<<"$keyscan"

  echo -n "${server[0]}"
}

# Usage:
#   ssh-keyscan-port
#
# Returns the port (if one is configured) for SSH key scanning. This value is empty if 1)
# there is no need to scan keys or 2) if the default port suffices. Thus, it is not safe
# to use the output of this function to determine if key scanning is needed.
ssh-keyscan-port() {
  local keyscan
  keyscan="$(get-config ssh keyscan)"

  if test -z "$keyscan"; then
    return
  fi

  local server
  IFS=: read -ra server <<<"$keyscan"

  if test "${#server[@]}" -gt 1; then
    echo -n "${server[1]}"
  fi

  # If we've reached this point, then we assume the user only wrote keyscan: HOST in their
  # config. Falling off the end of this function implies no output.
}

# Usage:
#   ssh-perform-keyscan FILE
#
# FILE: A file in which to store the host's keys.
#
# Performs an SSH keyscan using the plugin configuration. Keys are written to FILE in
# order to avoid polluting the agent's SSH known_hosts.
ssh-perform-keyscan() {
  local host
  host="$(ssh-keyscan-host)"

  local port
  port="$(ssh-keyscan-port)"

  local file="$1"

  # Store arguments in an array because ssh-keyscan gets very cranky if we don't put
  # options before arguments.
  local -a args=()

  if test -n "$port"; then
    args+=(-p "$port")
  fi

  args+=("$host")

  # $sep is ":" if $port is non-empty, and "" otherwise
  local sep="${port:+:}"

  header "Retrieving keys from $host$sep$port..."
  ssh-keyscan "${args[@]}" >"$file"
}
