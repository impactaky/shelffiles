FROM nixos/nix:2.24.14

# Enable flakes
RUN mkdir -p /etc/nix && \
    echo 'experimental-features = nix-command flakes' >> /etc/nix/nix.conf

# Set up working directory
WORKDIR /app

# Copy only the files needed for nix build
COPY flake.nix .
COPY test/packages.nix ./packages.nix

# Create necessary directories and build
RUN nix build

# Copy required files after nix build
COPY entrypoint ./entrypoint/
COPY test/config ./config/
COPY test/test ./test/

ENV PATH="/app/result/bin:$PATH"

# Make scripts executable and run tests
RUN bats test
