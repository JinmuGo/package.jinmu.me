#!/bin/sh
set -e

REPO_URL="https://package.jinmu.me"
REPO_NAME="jinmugo"

# Legacy file names that may conflict
LEGACY_NAMES="sls"

info()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
err()   { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# --- detect distro family ---
detect_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID $ID_LIKE" in
      *debian*|*ubuntu*) echo "deb" ;;
      *fedora*|*rhel*|*centos*|*rocky*|*alma*) echo "rpm" ;;
      *) err "Unsupported distro: $ID" ;;
    esac
  elif command -v apt-get >/dev/null 2>&1; then
    echo "deb"
  elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
    echo "rpm"
  else
    err "Could not detect package manager"
  fi
}

# --- clean up legacy repo files ---
cleanup_legacy() {
  for name in $LEGACY_NAMES; do
    if [ "$1" = "deb" ]; then
      rm -f "/etc/apt/keyrings/${name}.gpg"
      rm -f "/etc/apt/sources.list.d/${name}.list"
    elif [ "$1" = "rpm" ]; then
      rm -f "/etc/yum.repos.d/${name}.repo"
    fi
  done
}

# --- apt setup ---
setup_deb() {
  if [ -f "/etc/apt/sources.list.d/${REPO_NAME}.list" ]; then
    info "Repository already configured"
    return
  fi

  info "Setting up apt repository..."
  apt-get update -qq -o Dir::Etc::sourcelist=/dev/null -o Dir::Etc::sourceparts=/dev/null >/dev/null 2>&1 || true
  apt-get install -y -qq curl gnupg >/dev/null 2>&1

  mkdir -p /etc/apt/keyrings
  curl -fsSL "${REPO_URL}/gpg.key" | gpg --dearmor -o "/etc/apt/keyrings/${REPO_NAME}.gpg"
  echo "deb [signed-by=/etc/apt/keyrings/${REPO_NAME}.gpg] ${REPO_URL}/deb stable main" \
    > "/etc/apt/sources.list.d/${REPO_NAME}.list"

  info "Repository added"
}

# --- yum/dnf setup ---
setup_rpm() {
  if [ -f "/etc/yum.repos.d/${REPO_NAME}.repo" ]; then
    info "Repository already configured"
    return
  fi

  info "Setting up yum/dnf repository..."
  cat > "/etc/yum.repos.d/${REPO_NAME}.repo" << EOF
[${REPO_NAME}]
name=${REPO_NAME}
baseurl=${REPO_URL}/rpm
enabled=1
gpgcheck=1
gpgkey=${REPO_URL}/gpg.key
EOF

  info "Repository added"
}

# --- install package ---
install_pkg() {
  if [ -z "$1" ]; then return; fi

  if [ "$2" = "deb" ]; then
    info "Installing $1..."
    apt-get update -qq >/dev/null 2>&1
    apt-get install -y "$1"
  elif [ "$2" = "rpm" ]; then
    info "Installing $1..."
    if command -v dnf >/dev/null 2>&1; then
      dnf install -y "$1"
    else
      yum install -y "$1"
    fi
  fi
}

# --- main ---
DISTRO=$(detect_distro)
PKG="$1"

cleanup_legacy "$DISTRO"

if [ "$DISTRO" = "deb" ]; then
  setup_deb
elif [ "$DISTRO" = "rpm" ]; then
  setup_rpm
fi

install_pkg "$PKG" "$DISTRO"

info "Done!"
