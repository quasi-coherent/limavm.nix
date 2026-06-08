{
  flake,
  attr,
  marker ? "/var/lib/lima-bootstrap.done",
}:
''
  set -eu
  MARKER=${marker}
  if [ -f "$MARKER" ]; then
    echo "lima-bootstrap: already converged ($MARKER)"
    exit 0
  fi
  nixos-rebuild switch --flake "${flake}#${attr}"
  mkdir -p "$(dirname "$MARKER")"
  touch "$MARKER"
''
