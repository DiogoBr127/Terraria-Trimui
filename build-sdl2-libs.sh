#!/bin/bash
# Roda DENTRO de um container Debian bullseye arm64 (glibc 2.31, igual ao Smart Pro).
# Gera libFNA3D e libFAudio linkadas ao SDL2 em /out.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
# bullseye saiu de suporte: usa o arquivo historico do Debian
rm -f /etc/apt/sources.list.d/*
cat > /etc/apt/sources.list <<'EOL'
deb http://archive.debian.org/debian bullseye main
deb http://archive.debian.org/debian bullseye-updates main
deb http://archive.debian.org/debian-security bullseye-security main
EOL
apt-get -o Acquire::Check-Valid-Until=false update
apt-get -y --no-install-recommends dist-upgrade
apt-get install -y --no-install-recommends build-essential cmake git ca-certificates libsdl2-dev pkg-config

TAG="${FNA_TAG:-26.06}"   # mesma versao das libs do port (libFNA3D.so.0.26.06)
cd /tmp
git clone --recursive --branch "$TAG" --depth 1 https://github.com/FNA-XNA/FNA3D.git
git clone --recursive --branch "$TAG" --depth 1 https://github.com/FNA-XNA/FAudio.git

for lib in FNA3D FAudio; do
  echo "=== $lib: opcoes SDL no CMakeLists ==="
  grep -n -i 'sdl' "$lib/CMakeLists.txt" | head -20 || true
  # Se a opcao tiver outro nome, ajuste -DBUILD_SDL3=OFF abaixo conforme a linha acima.
  cmake -S "$lib" -B "build-$lib" -DCMAKE_BUILD_TYPE=Release -DBUILD_SDL3=OFF
  cmake --build "build-$lib" -j"$(nproc)"
done

mkdir -p /out
for lib in FNA3D FAudio; do
  f="$(ls build-$lib/lib${lib}.so.* 2>/dev/null | head -n1 || true)"
  [ -z "$f" ] && f="build-$lib/lib${lib}.so"
  cp -L "$f" "/out/lib${lib}.so.0"
  cp -L "$f" "/out/lib${lib}.so"
  echo "--- NEEDED de $lib (deve listar libSDL2, NAO libSDL3):"
  readelf -d "/out/lib${lib}.so" | grep NEEDED
done
