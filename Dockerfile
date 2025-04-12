FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required dependencies
RUN apt-get update && apt-get install -y \
    g++ \
    python3 \
    python3-dev \
    git \
    cmake \
    ninja-build \
    ccache \
    libboost-all-dev \
    pkg-config \
    sqlite3 \
    libsqlite3-dev \
    libxml2 \
    libxml2-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create a working directory
WORKDIR /ns3

# Download and extract NS-3
RUN git clone --branch ns-3.44 https://gitlab.com/nsnam/ns-3-dev.git . && \
    ./ns3 configure --enable-examples --enable-tests && \
    ./ns3 build

# Copy our simulation code
COPY src/p2pool-sim.cc scratch/

# Build the simulation
RUN ./ns3 build scratch/p2pool-sim

# Set up entry point
ENTRYPOINT ["./ns3", "run", "scratch/p2pool-sim"]
CMD ["--nNodes=50", "--simDuration=600"]
