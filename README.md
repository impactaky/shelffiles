# Shelffiles

Shelffiles is a portable environment configuration system that uses Nix to manage packages and configuration files. It's designed to be easy to set up and use across different systems.

## Features

- **Portable**: Works on any system with Nix installed
- **No symlinks**: All configuration files are contained within the repository
- **Nix integration**: Uses Nix flakes for reproducible package management
- **Simple package configuration**: Easily customize your environment through a single configuration file
- **Built-in debugging**: Troubleshoot configuration issues with helpful debug output

## Getting Started

### Prerequisites

- [Nix package manager](https://nixos.org/download.html) with flakes enabled

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/shelffiles.git
   cd shelffiles
   ```

2. Build the environment:
   ```bash
   nix build
   ```

3. Enter the environment:
   ```bash
   ./entrypoint.sh
   ```

## Customization

### Adding Packages

Edit the `config/nix/packages.nix` file to add or remove packages:

```nix
pkgs: with pkgs; [
  # Core utilities
  git      # Version control system
  ripgrep  # Fast text search tool
  fzf      # Command-line fuzzy finder
  
  # Uncomment or add packages you need
  # zsh       # Z Shell
  # neovim    # Vim-based text editor
  # nodejs    # Node.js runtime
]
```

After modifying the package list, rebuild the environment with:

```bash
nix build
```

> Note: If you want to keep your package configuration private, consider adding `/config/nix/packages.nix` to your `.gitignore` file.

### Adding Configuration Files

To add your own configuration files:

1. Create the appropriate directory structure in the repository:
   ```bash
   mkdir -p config/app-name
   ```

2. Add your configuration files to this directory:
   ```bash
   # Example: Adding a Neovim configuration
   mkdir -p config/nvim
   touch config/nvim/init.lua
   
   # Example: Adding a Git configuration
   mkdir -p config/git
   touch config/git/config
   ```

3. Edit the configuration files with your preferred settings:
   ```bash
   # Example: Basic Neovim configuration
   echo 'vim.opt.number = true' > config/nvim/init.lua
   
   # Example: Basic Git configuration
   cat > config/git/config << EOF
   [user]
       name = Your Name
       email = your.email@example.com
   [core]
       editor = vim
   EOF
   ```

When you enter the environment using `./entrypoint.sh`, these configuration files will be used automatically because the script sets the appropriate XDG environment variables to point to the directories within the repository.

### Finding Available Packages

To find available packages that you can add to your configuration:

1. **Search on the Nixpkgs website**:
   - Visit [search.nixos.org](https://search.nixos.org/packages) to search for packages
   - The package name shown in the search results is what you should add to your `packages.nix` file

2. **Search using the command line**:
   ```bash
   nix search nixpkgs package-name
   ```

3. **Browse the Nixpkgs repository**:
   - Visit the [Nixpkgs GitHub repository](https://github.com/NixOS/nixpkgs) to explore available packages
   - Packages are organized by category in the `pkgs` directory

## Directory Structure

```
shelffiles/
├── config/           # Configuration files
│   └── nix/          # Nix-related configuration
│       └── packages.nix  # Package definitions
├── cache/            # XDG_CACHE_HOME
├── share/            # XDG_DATA_HOME
├── state/            # XDG_STATE_HOME
├── entrypoint.sh     # Script to enter the environment
└── flake.nix         # Nix flake configuration
```

## How It Works

Shelffiles works by:

1. Setting XDG environment variables to point to directories within the repository
2. Using Nix flakes to manage packages in a reproducible way
3. Providing a consistent environment across different systems
4. Using a central package configuration file for easy customization
