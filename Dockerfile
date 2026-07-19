ARG UBUNTU_IMAGE=ubuntu:26.04@sha256:7c2884fd32770fc6c173b78e0dc2278a2851d89f5447919edbc45475ac55dd6a

FROM ${UBUNTU_IMAGE} AS build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /src
COPY pause.c .

RUN gcc -O2 -Wall -Wextra -Werror -D_FORTIFY_SOURCE=3 -fstack-protector-strong -fPIE -pie \
        -Wl,-z,relro -Wl,-z,now -Wl,--build-id=none -o /out-pause pause.c \
    && strip /out-pause

FROM ${UBUNTU_IMAGE}

ARG IMAGE_VERSION=v3.0.1-pasturestack.1
ARG SOURCE_REVISION=unknown

LABEL org.opencontainers.image.title="PastureStack Pod Pause Image" \
      org.opencontainers.image.description="Minimal pod infrastructure pause process maintained by PastureStack." \
      org.opencontainers.image.source="https://github.com/PastureStack/pod-pause-image" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${SOURCE_REVISION}" \
      org.opencontainers.image.base.name="docker.io/library/ubuntu:26.04"

RUN rm -f /usr/bin/pebble

COPY --from=build /out-pause /pause
COPY LICENSE /usr/share/licenses/pod-pause-image/LICENSE

USER 65532:65532
ENTRYPOINT ["/pause"]
