#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
HERE="$(pwd)"

CC=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d ' .')
NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
echo "GPU: $NAME (compute capability $CC)"

echo "Installing build tools..."
apt-get update -qq
apt-get install -y -qq --no-install-recommends git build-essential g++-9 curl ca-certificates python3

echo "Fetching source..."
rm -rf /tmp/vs-src
git clone --depth 1 -q https://github.com/ilkerccom/VanitySearch-V2.git /tmp/vs-src

echo "Building for sm_$CC (takes a few minutes)..."
cd /tmp/vs-src
make gpu=1 ccap=$CC CUDA=/usr/local/cuda CXX=g++-9 CXXCUDA=/usr/bin/g++-9 all
mv vanitysearch "$HERE/vanitysearch"
cd "$HERE"

echo "Verifying build with a known key..."
rm -f /tmp/tv.txt
./vanitysearch -gpu -gpuId 0 -t 0 -stop -o /tmp/tv.txt \
  --keyspace 10000000000:+FFFFFFF 1LwH6ihNbW67UYhzjcCy2RGwJR8Qao1SeV >/dev/null 2>&1 || true

if grep -q 10000ABCDEF /tmp/tv.txt 2>/dev/null; then
  echo ""
  echo "SETUP OK - build verified. Now run ./scan.sh"
else
  echo ""
  echo "SETUP FAILED - build cannot find a known test key. Do not scan with it."
  exit 1
fi
