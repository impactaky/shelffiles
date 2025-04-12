FROM nixos/nix

# Enable flakes
RUN mkdir -p /etc/nix && \
    echo 'experimental-features = nix-command flakes' >> /etc/nix/nix.conf

# Set up working directory
WORKDIR /app

# Copy only the files needed for nix build
COPY flake.nix .
COPY test/config/nix ./config/nix

# Create necessary directories and build
RUN nix build

# Copy required files after nix build
COPY entrypoint ./entrypoint/
COPY test/config ./config/
COPY test/test ./test/

ENV PATH="/app/result/bin:$PATH"

# Make scripts executable and run tests
RUN chmod +x entrypoint/* && \
    bats test

# CMD is not needed as tests run during build

# # Remove CMD as tests are run during build
# # CMD ["./test/test.sh", "bash"] 
