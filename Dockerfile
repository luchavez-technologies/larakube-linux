# The larakube-ubuntu WSL distro, as a root filesystem. `scripts/build.sh` exports it to a tarball that Windows imports with
# `wsl --import larakube-ubuntu <folder> larakube-ubuntu-<arch>.tar.gz`. It holds only what the CLI's LOCAL commands
# (cluster, up/down, new, build, exec, trust) need inside WSL: the CLI, k3s, kubectl, git, ssh, the GitHub CLI and
# rootless Podman. Cloud tooling (OpenTofu, AWS/Google Cloud CLIs, k9s, Tea) runs on the Windows host instead, and
# ~/.kube is linked to the host's, so both sides share one kubeconfig.
FROM ubuntu:24.04

# canary, or a release tag such as v0.34.0 (what larakube-cli publishes its binaries under)
ARG LARAKUBE_RELEASE=canary

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        systemd systemd-sysv libpam-systemd dbus dbus-user-session sudo ca-certificates curl git openssh-client unzip jq less locales tzdata gnupg \
        podman slirp4netns passt fuse-overlayfs uidmap iproute2 iptables \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# The WSL kernel has no loadable modules, so this unit always fails and leaves the system "degraded".
RUN ln -sf /dev/null /etc/systemd/system/kmod-static-nodes.service

# The same sources the CLI itself installs from: the current stable kubectl and k3s.
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"; \
    curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${version}/bin/linux/${arch}/kubectl"; \
    chmod +x /usr/local/bin/kubectl; \
    curl -fsSL https://get.k3s.io | INSTALL_K3S_SKIP_START=true INSTALL_K3S_SKIP_ENABLE=true sh -s - --disable=traefik --write-kubeconfig-mode=644

# The GitHub CLI (`gh`), the current release when the image is built.
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/cli/cli/releases/latest | sed 's#.*/tag/##')"; \
    version="${tag#v}"; \
    curl -fsSL "https://github.com/cli/cli/releases/download/${tag}/gh_${version}_linux_${arch}.tar.gz" | tar -xz -C /tmp; \
    install -m 0755 "/tmp/gh_${version}_linux_${arch}/bin/gh" /usr/local/bin/gh; \
    rm -rf "/tmp/gh_${version}_linux_${arch}"

RUN set -eux; \
    case "$(dpkg --print-architecture)" in amd64) asset=x64 ;; arm64) asset=arm ;; *) echo "unsupported architecture" >&2; exit 1 ;; esac; \
    curl -fsSL -o /usr/local/bin/larakube "https://github.com/luchavez-technologies/larakube-cli/releases/download/${LARAKUBE_RELEASE}/larakube-linux-${asset}"; \
    chmod +x /usr/local/bin/larakube

# The login every command runs as: no password (nothing in the app can answer a prompt), and the sub-id ranges and
# lingering that rootless Podman needs.
# The Ubuntu image ships a user called `ubuntu` at UID 1000, which this login replaces.
RUN set -eux; \
    userdel --remove ubuntu; \
    useradd --create-home --uid 1000 --shell /bin/bash larakube; \
    echo 'larakube ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/larakube; \
    chmod 0440 /etc/sudoers.d/larakube; \
    usermod --add-subuids 100000-165535 --add-subgids 100000-165535 larakube; \
    mkdir -p /var/lib/systemd/linger; touch /var/lib/systemd/linger/larakube; \
    mkdir -p /home/larakube/projects; chown larakube:larakube /home/larakube/projects

COPY wsl.conf /etc/wsl.conf

# What went in, for the setup screen and for bug reports.
RUN set -eux; \
    printf '{"larakube":"%s","kubectl":"%s","k3s":"%s","gh":"%s","podman":"%s","base":"%s"}\n' \
        "$(/usr/local/bin/larakube --version 2>/dev/null | tail -1 | tr -d '"')" \
        "$(kubectl version --client -o json | jq -r .clientVersion.gitVersion)" \
        "$(k3s --version 2>/dev/null | awk 'NR==1 {print $3}')" \
        "$(gh --version | awk 'NR==1 {print $3}')" \
        "$(podman --version | awk '{print $3}')" \
        "$(. /etc/os-release && echo "$VERSION_ID")" \
        > /etc/larakube-rootfs.json
