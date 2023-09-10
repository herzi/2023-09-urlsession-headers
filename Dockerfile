#
# Multi-Stage Dockerfile Overview (generated using [asciiflow.com](https://asciiflow.com)):
#
# ┌───────────────┐   ┌───────────────┐   ┌───────────────┐
# │     build     ├─┬►│ build-testing ├──►│    testing    │
# └───────────────┘ │ └───────────────┘   └───────────────┘
#                   │ ┌───────────────┐   ┌───────────────┐
#                   └►│build-inspector├──►│   inspector   │
#                     └───────────────┘   └───────────────┘
#
# - build:
#   Prepare swift container, add files, resolve dependencies, copy code
# - build-inspector:
#   Compile inspector tool
# - build-testing:
#   Precompile tests
# - inspector:
#   Image running the Service
# - testing:
#   Image running the integration tests

# ================================
# Shared Build Image
# ================================
FROM swift:5.8-jammy as build
# Install OS updates and, if needed, sqlite3
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y\
    && rm -rf /var/lib/apt/lists/*

# Set up a build area
WORKDIR /build

# First just resolve dependencies.
# This creates a cached layer that can be reused
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./Package.* ./
RUN swift package resolve

# Copy entire repo into container
COPY . .

# ================================
# Build Image for Inspector
# ================================
FROM build as build-inspector

# Build everything, with optimizations
RUN swift build -c release --static-swift-stdlib --product inspector

# Switch to the staging area
WORKDIR /staging

# Copy main executable to staging area
RUN cp "$(swift build --package-path /build -c release --show-bin-path)/inspector" ./

# Copy resources bundled by SPM to staging area
# RUN find -L "$(swift build --package-path /build -c release --show-bin-path)/" -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# ================================
# Build Image for Tests
# ================================
FROM build as build-testing

# Build Tests Only
RUN swift test --skip .

# Switch to the staging area
WORKDIR /staging

# Copy main executable to staging area
RUN cp "$(swift build --package-path /build -c debug --show-bin-path)"/2023-09-urlsession-headersPackageTests.xctest ./

# ================================
# Run Image for Inspector
# ================================
FROM ubuntu:jammy as inspector

# Make sure all system packages are up to date, and install only essential packages.
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q install -y \
      ca-certificates \
      tzdata \
# If your app or its dependencies import FoundationNetworking, also install `libcurl4`.
      # libcurl4 \
# If your app or its dependencies import FoundationXML, also install `libxml2`.
      # libxml2 \
    && rm -r /var/lib/apt/lists/*

# Create a vapor user and group with /app as its home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /inspector inspector

# Switch to the new home directory
WORKDIR /inspector

# Copy built executable and any staged resources from builder
COPY --from=build-inspector --chown=inspector:inspector /staging /inspector

# Ensure all further commands run as the vapor user
USER inspector:inspector

# Let Docker bind to port 8080
EXPOSE 8080

# Start the Vapor service when the image is run, default to listening on 8080 in production environment
ENTRYPOINT ["./inspector"]

# ================================
# Run Image for Tests
# ================================
FROM swift:5.8-jammy-slim as testing

# Install OS updates and, if needed, sqlite3
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y\
    && rm -rf /var/lib/apt/lists/*

## Make sure all system packages are up to date, and install only essential packages.
#RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
#    && apt-get -q update \
#    && apt-get -q dist-upgrade -y \
#    && apt-get -q install -y \
#      ca-certificates \
#      tzdata \
## If your app or its dependencies import FoundationNetworking, also install `libcurl4`.
#      # libcurl4 \
## If your app or its dependencies import FoundationXML, also install `libxml2`.
#      # libxml2 \
#    && rm -r /var/lib/apt/lists/*

# Create a vapor user and group with /app as its home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /build testing

# Switch to the new home directory
WORKDIR /testing

# Copy built executable and any staged resources from builder
COPY --from=build-testing --chown=testing:testing /staging /testing

# Ensure all further commands run as the vapor user
USER testing:testing

# Start the Vapor service when the image is run, default to listening on 8080 in production environment
ENTRYPOINT ["./2023-09-urlsession-headersPackageTests.xctest"]
