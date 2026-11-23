# larakube-ubuntu

**LaraKube Linux**, the Linux system LaraKube Desktop runs on Windows. Users only ever see it called LaraKube Linux; `larakube-ubuntu` is its technical name, as the WSL distro (`wsl -l`), this repository, and the release image. It is based on the official Ubuntu 26.04 LTS image with what Desktop needs already installed, packed as a root filesystem tarball for `wsl --import`.

**You do not install this yourself.** LaraKube Desktop downloads it on first run, checks its checksum, and imports it. It never touches a distro you already have, and `wsl --unregister larakube-ubuntu` removes it.

## What is in it

- Ubuntu 26.04 LTS, systemd on (`wsl.conf`)
- The LaraKube CLI, kubectl and k3s
- The git forge CLIs: GitHub CLI (`gh`) and Tea CLI (`tea`), since projects (and their git work) live in the distro
- Rootless Podman, git and ssh
- The AWS and Google Cloud CLIs (with `gke-gcloud-auth-plugin`), which EKS/GKE kubeconfigs and ECR/GAR registry logins call
- A `larakube` login (UID 1000, no password), with a `projects` folder in its home
- `/etc/larakube-rootfs.json` listing the versions that went in

## Windows and LaraKube Linux

Projects live in here, so every project command runs in here, for every environment: `up`, `cloud:deploy production`, `dotenv:push`, and anything run from inside a project folder. Only commands that don't touch a project stay on the Windows host: provisioning with OpenTofu (`cloud:create`, `tls:*`), servers, Cluster Tools, and `setup`. Windows without LaraKube Linux is for servers and Cluster Tools only.

Both sides share one copy of everything that must agree. These are links to the Windows host's, made on the first dispatched command:
- `~/.kube` (one kubeconfig: the local k3s context at `https://127.0.0.1:6443` answers from both sides through WSL2's localhost forwarding);
- `~/.larakube/config.json` (servers, accounts, tokens);
- `~/.aws` and `~/.config/gcloud` (one cloud login).

Server SSH keys are read straight from `C:\Users\<you>\.ssh` through `/mnt/c`. The `metadata` mount option lets them be made 0600, which OpenSSH requires.

## Releases

| Release | When | Contains |
| --- | --- | --- |
| `canary` (prerelease, replaced each time) | a push to `main`, and every Monday | the CLI's canary build |
| `vYYYY.MM.DD` (latest) | the `stable` option of the workflow, by hand | the CLI's latest stable release |

Desktop downloads `releases/latest/download/larakube-ubuntu-amd64.tar.gz` and checks `larakube-ubuntu-amd64.tar.gz.sha256` next to it.

## Build and test it yourself

Needs Docker.

```bash
scripts/build.sh canary linux/amd64      # writes dist/larakube-ubuntu-amd64.tar.gz and its .sha256
scripts/smoke.sh dist/larakube-ubuntu-amd64.tar.gz linux/amd64
```

To try it on Windows by hand, in PowerShell:

```powershell
wsl --import larakube-ubuntu $env:LOCALAPPDATA\LaraKube\wsl .\larakube-ubuntu-amd64.tar.gz --version 2
wsl -d larakube-ubuntu -- larakube --version
```

## Why a distro of our own

A student's existing Ubuntu could be any version, with systemd off and none of our tools. A dedicated distro is the same for everyone, leaves their own distro alone, and is one command to remove. LaraKube Desktop does the same thing Docker Desktop does with its `docker-desktop` distro.

## License

The files in this repository are source-available under [`FSL-1.1-MIT`](LICENSE). The published image also contains Ubuntu and other third-party software, which keep their own licenses.
