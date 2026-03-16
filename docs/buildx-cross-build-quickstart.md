```bash
git clone https://github.com/iIIusi0n/jetson-containers.git
cd jetson-containers
git remote add upstream https://github.com/dusty-nv/jetson-containers.git
python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -r requirements.txt
docker buildx create --name jetson-buildx --driver docker-container --use
docker buildx inspect --bootstrap
docker run --privileged --rm tonistiigi/binfmt --install arm64
export DOCKER_BUILDKIT=1
export BUILDX_BUILDER=jetson-buildx
export SYSTEM_ARCH=aarch64
export CUDA_ARCH=tegra-aarch64
export L4T_VERSION=36.4.4
export LSB_RELEASE=24.04
./jetson-containers build --platform=linux/arm64 pytorch
```
