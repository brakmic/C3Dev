# C3 Programming Language Development Container

A Docker development environment for the [C3 programming language](https://c3-lang.org/), built on Ubuntu 26.04 (Resolute Raccoon).

## What's Included

### Core Development Tools

- **C3 Compiler** - Pinned stable release (0.8.5_1) with LSP support, verified by SHA-256 at build time
- **GCC 15** - Modern C/C++ compiler (system default)
- **Clang & LLD** - C compiler and linker for C interop and the experimental C backend added in C3 0.8.5
- **Node.js 24** - Current LTS line (Krypton) with npm, yarn, and TypeScript
- **Git & Git LFS** - Version control with large file support
- **OpenSSH Client** - `ssh` and `ssh-keygen` for Git over SSH
- **libmicrohttpd** - Development headers for the C3 web server example
- **Docker** - Container runtime

### Development Utilities

- **WebAssembly Tools** (WABT) - `wasm2wat`, `wat2wasm`, `wasm-validate`
- **Build Tools** - CMake, Ninja, Make
- **Debugging** - GDB, Valgrind, Strace
- **Network Tools** - curl, wget, netcat, ping, dig
- **File Management** - lsd (modern ls), nano with syntax highlighting

### VS Code Integration

- Pre-configured C3 language extension
- Optimized settings for C3 development
- Dev container support with proper user permissions

## Quick Start

### Using Pre-built Image

```bash
# Pull the latest image
docker pull brakmic/c3dev:latest

# Run interactively
docker run -it --rm \
  -v $(pwd):/workspace \
  brakmic/c3dev:latest
```

### Using with VS Code Dev Containers

1. **Create devcontainer.json**:

```jsonc
{
  "name": "C3 Development Environment",
  "image": "brakmic/c3dev:latest",
  "workspaceFolder": "/workspace",
  "workspaceMount": "source=${localWorkspaceFolder},target=/host_workspace,type=bind,consistency=cached",
  "customizations": {
    "vscode": {
      "extensions": [
        "c3.vscode-c3"
      ]
    }
  },
  "remoteUser": "c3dev"
}
```

1. **Open in VS Code**:
   - Install the "Dev Containers" extension
   - Open Command Palette (`Ctrl+Shift+P`)
   - Run: "Dev Containers: Reopen in Container"

## Building from Source

### Prerequisites

- Docker Engine 20.10+
- 4GB+ available disk space

### Build Commands

```bash
# Clone this repository
git clone https://github.com/brakmic/c3dev.git
cd c3dev

# Build the image
docker build -t c3dev-local .

# Or build with custom user
docker build --build-arg NONROOT_USER=myuser -t c3dev-local .
```

### Build Arguments

| Argument       | Default   | Description                       |
|----------------|-----------|-----------------------------------|
| `NONROOT_USER` | `c3dev`   | Non-root username                 |
| `NODE_VERSION` | `24`      | Node.js major version (LTS line)  |
| `C3_VERSION`   | `0.8.5_1` | C3 compiler release tag           |
| `LSD_VERSION`  | `1.2.0`   | lsd release version               |

`C3_SHA256` defaults to the published checksum of the pinned `c3-linux.tar.gz`; alongside the version, it must be updated when bumping `C3_VERSION`.

## Usage Examples

### Compile C3 Programs

```bash
# Check C3 compiler version
c3c --version

# Compile a simple program
echo 'module hello; import std::io; fn void main() { io::printn("Hello, C3!"); }' > hello.c3
c3c compile hello.c3
./hello
```

### WebAssembly Development

```bash
# Compile a WASM library (no main entry point)
c3c compile --target wasm32 --no-entry -o math math.c3

# Inspect WASM binary
wasm2wat math.wasm -o math.wat
wasm-validate math.wasm
```

## Directory Structure

```bash
/home/c3dev/
├── bin/c3/          # C3 compiler binaries
├── .bashrc          # Shell configuration
├── .bash_aliases    # Custom aliases
└── .nanorc          # Nano editor config

/workspace/          # Mounted project directory
```

## Environment Variables

| Variable | Value            | Description           |
|----------|------------------|-----------------------|
| `PATH`   | Includes c3      | C3 compiler in PATH   |
| `EDITOR` | `nano`           | Default text editor   |
| `TERM`   | `xterm-256color` | Terminal capabilities |

## Useful Aliases

The container includes helpful aliases:

```bash
ll      # ls -la
gs      # git status
ga      # git add
gp      # git push
gl      # git log
```

## Related Projects

- [C3 Language](https://c3-lang.org/) - The C3 programming language
- [C3 Compiler](https://github.com/c3lang/c3c) - Official C3 compiler
- [VS Code C3 Extension](https://marketplace.visualstudio.com/items?itemName=c3.vscode-c3) - C3 language support for VS Code
