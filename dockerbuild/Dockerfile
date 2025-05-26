# Stage 1: Build Environment
FROM debian:latest AS builder

# Define a build argument to control local mirror usage.
ARG USE_LOCAL_MIRROR=false
# TARGET_ARCH defaults to x86 (native) but can be set to "arm64" (or others later)
ARG TARGET_ARCH=x86
# CROSS_COMPILE_PREFIX should be set when cross compiling. For arm64, set to "aarch64-linux-gnu-"
ARG CROSS_COMPILE_PREFIX=

# Environment variables and noninteractive mode
ENV CCACHEVER=4.11.3
ENV DEBIAN_FRONTEND=noninteractive
ENV LLVM_VERSION=18

# Conditionally copy local apt mirror files if the build argument is set.
# Since COPY doesn't support conditionals, we use a RUN block instead.
# Make sure that sources.list and stargazer.auth are part of the build context (e.g., in dockerbuild/)
COPY sources.list /tmp/sources.list
COPY stargazer.auth /tmp/stargazer.auth

RUN if [ "$USE_LOCAL_MIRROR" = "true" ]; then \
      echo "Using local apt mirror configuration"; \
      cp /tmp/sources.list /etc/apt/sources.list && \
      cp /tmp/stargazer.auth /etc/apt/auth.conf.d/stargazer && \
      rm -f /etc/apt/sources.list.d/*; \
    else \
      echo "Skipping local apt mirror configuration"; \
    fi

# Initial update with cached mirror
RUN apt -o "Acquire::https::Verify-Peer=false" update && \
    apt -o "Acquire::https::Verify-Peer=false" install -y ca-certificates

# Install all required dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    lsb-release wget gnupg2 curl jq xz-utils build-essential \
    bc kmod cpio flex libncurses5-dev libelf-dev libssl-dev libdw-dev \
    dwarves bison cmake bash libzstd-dev libxxhash-dev rsync \
    debhelper git ruby rubygems equivs zip software-properties-common && \
    rm -rf /var/lib/apt/lists/*

# If the target architecture is not native, install the appropriate cross toolchain.
# For example, for arm64 (aarch64), install gcc-aarch64-linux-gnu and binutils-aarch64-linux-gnu.
RUN if [ "$TARGET_ARCH" != "x86" ]; then \
      if [ "$TARGET_ARCH" = "arm64" ]; then \
         apt-get update && apt-get install -y gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu; \
         echo "Cross-compiling for arm64"; \
      else \
         echo "Cross compilation for target architecture $TARGET_ARCH is not yet supported"; \
         exit 1; \
      fi; \
    else \
      echo "Native build for x86"; \
    fi

# Install LLVM using the apt script
RUN wget https://apt.llvm.org/llvm.sh && chmod +x llvm.sh && \
    ./llvm.sh ${LLVM_VERSION} && rm llvm.sh && \
    for bin in clang clang++ ld.lld llvm-ar llvm-nm llvm-objcopy llvm-readelf llvm-strip; do \
      update-alternatives --install /usr/bin/$bin $bin /usr/bin/${bin}-${LLVM_VERSION} 100; \
    done

# Build ccache from source
RUN mkdir -p /tmp/ccache && cd /tmp/ccache && \
    curl -L https://github.com/ccache/ccache/releases/download/v${CCACHEVER}/ccache-${CCACHEVER}.tar.gz | \
      tar xz --strip-components=1 && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DCMAKE_INSTALL_SYSCONFDIR=/etc \
          -DREDIS_STORAGE_BACKEND=OFF .. && \
    make -j$(nproc) && make install && \
    cd / && rm -rf /tmp/ccache

# Install CLI tools (like gh) and any Ruby gems
RUN gem install package_cloud && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
      gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Prepare build environment directories
RUN mkdir -p /build /config /release /patches

# Copy your kernel build script (which compiles the kernel and packages it, outputting artifacts to /release)
COPY kbuild2.sh /usr/local/bin/kbuild2
RUN chmod +x /usr/local/bin/kbuild2

# Set working directory for kernel build and run the build script
WORKDIR /build

# Set environment variables for the kernel build.
# For cross compile, these environment variables can be used by your kbuild2.sh script.
ENV ARCH=${TARGET_ARCH}
ENV CROSS_COMPILE=${CROSS_COMPILE_PREFIX}

ENTRYPOINT ["/usr/local/bin/kbuild2"]
