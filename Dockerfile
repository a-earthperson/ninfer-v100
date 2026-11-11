# syntax=docker/dockerfile:1

# sm_70 requires CUDA 12.8: CUDA 13.x no longer assembles Volta device code.
FROM nvidia/cuda:12.8.1-devel-ubuntu24.04 AS build

ARG DEBIAN_FRONTEND=noninteractive
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        cmake \
        git \
        python3 \
        libavcodec-dev \
        libavformat-dev \
        libavutil-dev \
        libcurl4-openssl-dev \
        libswscale-dev \
        ninja-build \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
# Only the inputs of the app build, so docs/compose/entrypoint edits do not invalidate the CUDA build.
COPY CMakeLists.txt ./
COPY include include
COPY src src
COPY apps apps
COPY third_party third_party

RUN cmake -S . -B /build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CUDA_ARCHITECTURES=70 \
        -DNINFER_BUILD_APPS=ON \
        -DBUILD_TESTING=OFF \
        -DNINFER_BUILD_BENCHMARKS=OFF \
    && cmake --build /build --parallel --target ninfer ninfer-serve

FROM nvidia/cuda:12.8.1-runtime-ubuntu24.04

ARG DEBIAN_FRONTEND=noninteractive
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        curl \
        libavcodec60 \
        libavformat60 \
        libavutil58 \
        libcurl4t64 \
        libswscale7 \
        python3 \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Model artifacts are fetched at container start (docker/entrypoint.sh), not baked into the image.
ARG HUGGINGFACE_HUB_SPEC="huggingface_hub>=0.34"
RUN python3 -m venv /opt/hf \
    && /opt/hf/bin/pip install --no-cache-dir "${HUGGINGFACE_HUB_SPEC}" \
    && ln -s /opt/hf/bin/hf /usr/local/bin/hf

COPY --from=build /build/apps/ninfer /usr/local/bin/ninfer
COPY --from=build /build/apps/ninfer-serve /usr/local/bin/ninfer-serve
COPY --chmod=0755 docker/entrypoint.sh /usr/local/bin/ninfer-entrypoint

ENV NINFER_MODEL_DIR=/models \
    HF_HOME=/var/cache/huggingface
VOLUME ["/models", "/var/cache/huggingface"]

WORKDIR /workspace
EXPOSE 8080
STOPSIGNAL SIGTERM

ENTRYPOINT ["ninfer-entrypoint"]
CMD ["ninfer-serve", "--help"]
