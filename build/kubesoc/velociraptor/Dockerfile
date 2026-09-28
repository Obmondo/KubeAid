# syntax=docker/dockerfile:1.7
#
# kubesoc Velociraptor image: the official Velocidex release binary on a
# distroless, non-root base. Nothing is compiled here; the binary is the one
# Velocidex publishes, checked against a pinned SHA-256 and the Velocidex
# release signature before it is copied into the image.
#
# Build with ./build.sh (reads versions.env). Runs as 65532:65532 with the
# binary as the entrypoint, like the image the velociraptor chart defaults to,
# so the chart's args work unchanged.

ARG FETCH_IMAGE=debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251
ARG RUNTIME_IMAGE=gcr.io/distroless/base-debian12:nonroot@sha256:7f0c72cd138b442ae0deeb69c08b1acf5525439ba251a49ad93c320a061567e5

FROM ${FETCH_IMAGE} AS fetch
ARG VELOCIRAPTOR_VERSION
ARG SHA256_AMD64
ARG SHA256_ARM64
# Primary key of "Velociraptor Team <support@velocidex.com>", the key every
# release asset's .sig is made with.
ARG VELOCIDEX_KEY_FPR=0572F28B4EF19A043F4CBBE0B22A7FB19CB6CFA1
ARG TARGETARCH
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && rm -rf /var/lib/apt/lists/*
COPY velocidex-release-key.asc /tmp/velocidex-release-key.asc
RUN set -eu; \
    test -n "${VELOCIRAPTOR_VERSION}" || { echo "VELOCIRAPTOR_VERSION is required" >&2; exit 1; }; \
    case "${TARGETARCH}" in \
      amd64) want="${SHA256_AMD64}" ;; \
      arm64) want="${SHA256_ARM64}" ;; \
      *) echo "unsupported architecture ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    test -n "${want}" || { echo "no pinned SHA-256 for ${TARGETARCH}" >&2; exit 1; }; \
    asset="velociraptor-v${VELOCIRAPTOR_VERSION}-linux-${TARGETARCH}"; \
    base="https://github.com/Velocidex/velociraptor/releases/download/v${VELOCIRAPTOR_VERSION}"; \
    curl -fsSL --retry 3 -o /tmp/velociraptor "${base}/${asset}"; \
    curl -fsSL --retry 3 -o /tmp/velociraptor.sig "${base}/${asset}.sig"; \
    echo "${want}  /tmp/velociraptor" | sha256sum -c -; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --quiet --import /tmp/velocidex-release-key.asc; \
    signer="$(gpg --batch --status-fd 1 --verify /tmp/velociraptor.sig /tmp/velociraptor 2>/dev/null | awk '$2 == "VALIDSIG" { print $NF }')"; \
    test "${signer}" = "${VELOCIDEX_KEY_FPR}" || { echo "bad or missing Velocidex signature (signer '${signer}')" >&2; exit 1; }; \
    chmod 0755 /tmp/velociraptor; \
    /tmp/velociraptor version | grep -q "version: ${VELOCIRAPTOR_VERSION}"

FROM ${RUNTIME_IMAGE}
ARG VELOCIRAPTOR_VERSION
LABEL org.opencontainers.image.title="kubesoc-velociraptor" \
      org.opencontainers.image.description="Velociraptor ${VELOCIRAPTOR_VERSION} (official Velocidex release binary, signature-verified) on distroless, non-root" \
      org.opencontainers.image.version="${VELOCIRAPTOR_VERSION}" \
      org.opencontainers.image.licenses="AGPL-3.0-or-later" \
      org.opencontainers.image.source="https://github.com/Obmondo/KubeAid"
COPY --from=fetch /tmp/velociraptor /velociraptor
USER 65532:65532
WORKDIR /home/nonroot
EXPOSE 8000 8001 8889
ENTRYPOINT ["/velociraptor"]
CMD ["--config", "/etc/velociraptor/server.config.yaml", "frontend", "-v"]
