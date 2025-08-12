#!/bin/bash
set -e

echo "Building numpy layer..."
rm -rf layers
mkdir -p layers/python

(
  cd layers || exit 1
  python3 -m venv venv
  source venv/bin/activate
  pip install numpy
  cp -r venv/lib ./python/
  deactivate
)

# go back to the repo root explicitly
cd "$(dirname "$0")"

echo "Zipping layer..."
cd layers && zip -r ../numpy-layer.zip python
