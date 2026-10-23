ARG UBUNTU_IMAGE=ubuntu:26.04@sha256:2260313b31c8c011cd2eebe728008efac1b3982be73eb71348ea2648d2c0e09b

FROM ${UBUNTU_IMAGE} AS snapshot-ca-bootstrap

ADD --checksum=sha256:5b6326f1932cfd7be57130561dc78192f09ed9f58bfbe6606ed0c50510c3b6cd \
    https://archive.ubuntu.com/ubuntu/pool/main/c/ca-certificates/ca-certificates_20260816ubuntu0.26.04.1_all.deb \
    /tmp/ca-certificates.deb

RUN set -eux; \
    rm -rf /tmp/ca-bootstrap; \
    mkdir -p /tmp/ca-bootstrap; \
    dpkg-deb --extract /tmp/ca-certificates.deb /tmp/ca-bootstrap; \
    find /tmp/ca-bootstrap/usr/share/ca-certificates -type f -name '*.crt' \
        | LC_ALL=C sort \
        | while IFS= read -r certificate; do sed -e '$a\' "${certificate}"; done \
        > /snapshot-ca-certificates.crt; \
    test -s /snapshot-ca-certificates.crt

FROM ${UBUNTU_IMAGE} AS build

ARG UBUNTU_APT_SNAPSHOT=20260909T000000Z

ENV DEBIAN_FRONTEND=noninteractive

COPY --from=snapshot-ca-bootstrap /snapshot-ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=snapshot-ca-bootstrap /tmp/ca-certificates.deb /tmp/ca-certificates.deb
COPY ubuntu-apt.lock /usr/share/pasturestack/manifests/ubuntu-apt.lock
COPY ubuntu-security-packages.lock /usr/share/pasturestack/manifests/ubuntu-security-packages.lock
COPY scripts/install-ubuntu-security-updates.sh /usr/local/libexec/install-ubuntu-security-updates

RUN set -eux; \
    . /usr/share/pasturestack/manifests/ubuntu-apt.lock; \
    test "${UBUNTU_APT_SNAPSHOT}" = "${UBUNTU_APT_LOCKED_SNAPSHOT}"; \
    rm -f /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; \
    printf 'Types: deb\nURIs: https://snapshot.ubuntu.com/ubuntu/%s\nSuites: resolute resolute-updates resolute-backports resolute-security\nComponents: main universe restricted multiverse\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\nSnapshot: no\n' \
        "${UBUNTU_APT_SNAPSHOT}" > /etc/apt/sources.list.d/pasturestack-snapshot.sources; \
    printf 'Acquire::Retries "5";\nAcquire::http::Timeout "30";\nAcquire::https::Timeout "30";\nAcquire::https::CaInfo "/etc/ssl/certs/ca-certificates.crt";\nAcquire::https::Verify-Peer "true";\nAcquire::https::Verify-Host "true";\nAcquire::AllowInsecureRepositories "false";\nAPT::Get::AllowUnauthenticated "false";\n' \
        > /etc/apt/apt.conf.d/80pasturestack-snapshot; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential="${UBUNTU_APT_BUILD_ESSENTIAL_VERSION}" \
        ca-certificates="${UBUNTU_APT_CA_CERTIFICATES_VERSION}" \
        dpkg-dev="${UBUNTU_APT_DPKG_DEV_VERSION}" \
        g++="${UBUNTU_APT_GPP_VERSION}" \
        gcc="${UBUNTU_APT_GCC_VERSION}" \
        libc6-dev="${UBUNTU_APT_LIBC6_DEV_VERSION}" \
        make="${UBUNTU_APT_MAKE_VERSION}"; \
    for package_and_version in \
        "build-essential=${UBUNTU_APT_BUILD_ESSENTIAL_VERSION}" \
        "ca-certificates=${UBUNTU_APT_CA_CERTIFICATES_VERSION}" \
        "dpkg-dev=${UBUNTU_APT_DPKG_DEV_VERSION}" \
        "g++=${UBUNTU_APT_GPP_VERSION}" \
        "gcc=${UBUNTU_APT_GCC_VERSION}" \
        "libc6-dev=${UBUNTU_APT_LIBC6_DEV_VERSION}" \
        "make=${UBUNTU_APT_MAKE_VERSION}"; do \
        package="${package_and_version%%=*}"; \
        expected="${package_and_version#*=}"; \
        test "$(dpkg-query -W -f='${Version}' "${package}")" = "${expected}"; \
    done; \
    dpkg -i /tmp/ca-certificates.deb; \
    test "$(dpkg-query -W -f='${Version}' ca-certificates)" = 20260816ubuntu0.26.04.1; \
    sh /usr/local/libexec/install-ubuntu-security-updates /usr/share/pasturestack/manifests/ubuntu-security-packages.lock /etc/ssl/certs/ca-certificates.crt; \
    { \
        printf 'record\tname\tarchitecture\tversion\n'; \
        printf 'metadata\tschema\t-\tpasturestack.dpkg-manifest/v1\n'; \
        printf 'metadata\tubuntu_snapshot\t-\t%s\n' "${UBUNTU_APT_SNAPSHOT}"; \
        dpkg-query -W -f='package\t${binary:Package}\t${Architecture}\t${Version}\n' | LC_ALL=C sort; \
    } > /usr/share/pasturestack/manifests/builder-ubuntu-packages.tsv; \
    { \
        printf 'component\tpackage_version\tinstalled_version\n'; \
        printf 'build-essential\t%s\t%s\n' "${UBUNTU_APT_BUILD_ESSENTIAL_VERSION}" "$(dpkg-query -W -f='${Version}' build-essential)"; \
        printf 'gcc\t%s\t%s\n' "${UBUNTU_APT_GCC_VERSION}" "$(gcc -dumpfullversion -dumpversion)"; \
        printf 'g++\t%s\t%s\n' "${UBUNTU_APT_GPP_VERSION}" "$(g++ -dumpfullversion -dumpversion)"; \
    } > /usr/share/pasturestack/manifests/builder-toolchain.tsv; \
    rm -f /usr/bin/pebble; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*; \
    rm -f /var/log/apt/* /var/log/dpkg.log /var/log/alternatives.log /var/cache/ldconfig/aux-cache

WORKDIR /src
COPY pause.c .

RUN gcc -O2 -Wall -Wextra -Werror -D_FORTIFY_SOURCE=3 -fstack-protector-strong -fPIE -pie \
        -Wl,-z,relro -Wl,-z,now -Wl,--build-id=none -o /out-pause pause.c \
    && strip /out-pause

FROM ${UBUNTU_IMAGE}

ARG IMAGE_VERSION=v3.0.4
ARG SOURCE_REVISION=unknown
ARG UBUNTU_IMAGE

LABEL org.opencontainers.image.title="PastureStack Pod Pause Image" \
      org.opencontainers.image.description="Minimal pod infrastructure pause process maintained by PastureStack." \
      org.opencontainers.image.source="https://github.com/PastureStack/pod-pause-image" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${SOURCE_REVISION}" \
      org.opencontainers.image.base.name="docker.io/library/ubuntu:26.04"

COPY --from=snapshot-ca-bootstrap /snapshot-ca-certificates.crt /tmp/security-ca-bundle.crt
COPY ubuntu-security-packages.lock /usr/share/pasturestack/manifests/ubuntu-security-packages.lock
COPY scripts/install-ubuntu-security-updates.sh /tmp/install-ubuntu-security-updates.sh

RUN set -eux; \
    sh /tmp/install-ubuntu-security-updates.sh /usr/share/pasturestack/manifests/ubuntu-security-packages.lock /tmp/security-ca-bundle.crt; \
    mkdir -p /usr/share/pasturestack/manifests; \
    { \
        printf 'record\tname\tarchitecture\tversion\n'; \
        printf 'metadata\tschema\t-\tpasturestack.dpkg-manifest/v1\n'; \
        printf 'metadata\tbase_image\t-\t%s\n' "${UBUNTU_IMAGE}"; \
        dpkg-query -W -f='package\t${binary:Package}\t${Architecture}\t${Version}\n' | LC_ALL=C sort; \
    } > /usr/share/pasturestack/manifests/runtime-ubuntu-packages.tsv; \
    rm -f /usr/bin/pebble /tmp/security-ca-bundle.crt /tmp/install-ubuntu-security-updates.sh; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    rm -f /var/log/apt/* /var/log/dpkg.log /var/log/alternatives.log /var/cache/ldconfig/aux-cache

COPY --from=build /out-pause /pause
COPY --from=build /usr/share/pasturestack/manifests/ /usr/share/pasturestack/manifests/
COPY LICENSE /usr/share/licenses/pod-pause-image/LICENSE

USER 65532:65532
ENTRYPOINT ["/pause"]
