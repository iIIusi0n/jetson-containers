#!/usr/bin/env bash
set -ex

apt_update_retry() {
  local attempt=1
  local max_attempts=5
  local delay=15

  while (( attempt <= max_attempts )); do
    if apt-get update; then
      return 0
    fi

    if (( attempt == max_attempts )); then
      return 1
    fi

    echo "apt-get update failed (attempt ${attempt}/${max_attempts}), retrying in ${delay}s..."
    sleep "${delay}"
    attempt=$((attempt + 1))
  done
}

echo "##### 🏢 \$PYTORCH_OFFICIAL_WHL is $PYTORCH_OFFICIAL_WHL #####"

# install prerequisites
apt_update_retry
if [[ "$IS_SBSA" == "True" ]]; then
  echo "SBSA system detected - using NVPL BLAS, skipping OpenBLAS"
  apt-get install -y --no-install-recommends \
          libomp-dev
else
  echo "Non-SBSA system - installing OpenBLAS"
  apt-get install -y --no-install-recommends \
          libopenblas-dev \
          libomp-dev
fi

if [ $USE_MPI == 1 ]; then
  apt-get install -y --no-install-recommends \
          libopenmpi-dev \
          openmpi-bin \
          openmpi-common \
          gfortran
fi

UBUNTU_VERSION=$(grep VERSION_ID /etc/os-release | cut -d '"' -f 2)

if [[ "$UBUNTU_VERSION" == "22.04" ]]; then
  echo "🟢 Ubuntu 22.04 detected — installing GCC 13 for GLIBCXX_3.4.32"

  apt_update_retry
  apt-get install -y --no-install-recommends \
    software-properties-common \
    curl \
    wget \
    ca-certificates

  add-apt-repository ppa:ubuntu-toolchain-r/test -y
  apt_update_retry
  apt install -y g++-13 libstdc++-13-dev libstdc++6

  STDCPP_SO=$(find /usr/lib/aarch64-linux-gnu -name 'libstdc++.so.6.0.*' | sort -V | tail -n1)
  ln -sf "$STDCPP_SO" /usr/lib/aarch64-linux-gnu/libstdc++.so.6
  export LD_LIBRARY_PATH=/usr/lib/aarch64-linux-gnu:$LD_LIBRARY_PATH
  strings "$STDCPP_SO" | grep GLIBCXX_3.4.32

else
  echo "🔶 Ubuntu version is $UBUNTU_VERSION — skipping GCC upgrade"
fi

rm -rf /var/lib/apt/lists/*
apt-get clean

if [ "$FORCE_BUILD" == "on" ]; then
	echo "Forcing build of PyTorch ${PYTORCH_BUILD_VERSION}"
	exit 1
fi

if [ "$PYTORCH_OFFICIAL_WHL" == "on" ]; then
	echo "##### 🏢Using official PyTorch 2.10 WHL #####"
  uv pip install torch==2.10.0 --index-url https://download.pytorch.org/whl/cu130
else
  # on x86_64, install from pytorch nightly server
  # on aarch64, install from the Jetson pypi server ($PIP_INSTALL_URL)
  uv pip install torch==${TORCH_VERSION} || \
  uv pip install --prerelease=allow "torch>=${PYTORCH_BUILD_VERSION}.dev,<=${PYTORCH_BUILD_VERSION}"
fi

if [ "${JETSON_CROSS_BUILD:-0}" = "1" ]; then
  echo "Skipping live CUDA runtime probe during cross-build (${JETSON_TARGET_PLATFORM:-unknown})"
  uv pip show torch
  python3 - <<'PY'
from importlib import metadata

print(f"PyTorch version: {metadata.version('torch')}")
PY
else
  # make sure it loads on native builds
  python3 -c 'import torch; \
      print(f"PyTorch version: {torch.__version__}"); \
      print(f"CUDA device #  : {torch.cuda.device_count()}"); \
      print(f"CUDA version   : {torch.version.cuda}"); \
      print(f"cuDNN version  : {torch.backends.cudnn.version()}");'
fi

# PyTorch C++ extensions frequently use ninja parallel builds
uv pip install scikit-build ninja
