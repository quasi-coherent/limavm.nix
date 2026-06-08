{
  flake,
  attr,
  marker ? "/var/lib/lima-bootstrap.done",
}:
''
  set -eu
  export PATH=/run/current-system/sw/bin:$PATH
  MARKER=${marker}
  if [ -f "$MARKER" ]; then
    echo "lima-bootstrap: already converged ($MARKER)"
    exit 0
  fi
  nixos-rebuild switch --flake "${flake}#${attr}"
  mkdir -p "$(dirname "$MARKER")"
  touch "$MARKER"
''
