#!/bin/bash

# NS-3 version and path definitions
NS3_VERSION="3.44"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS3_DIR="$SCRIPT_DIR/../ns-allinone-$NS3_VERSION/ns-$NS3_VERSION"
NS3_URL="https://www.nsnam.org/releases/ns-allinone-$NS3_VERSION.tar.bz2"
NS3_ARCHIVE="$SCRIPT_DIR/../ns-allinone-$NS3_VERSION.tar.bz2"

# Default simulation parameters
NODES=50
LATENCY_MEAN=0.1
LATENCY_STD=0.02
SHARE_MEAN=10.0
SHARE_STD=2.0
SIM_DURATION=600

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --nNodes=*)
      NODES="${1#*=}"
      shift
      ;;
    --latencyMean=*)
      LATENCY_MEAN="${1#*=}"
      shift
      ;;
    --latencyStd=*)
      LATENCY_STD="${1#*=}"
      shift
      ;;
    --shareMean=*)
      SHARE_MEAN="${1#*=}"
      shift
      ;;
    --shareStd=*)
      SHARE_STD="${1#*=}"
      shift
      ;;
    --simDuration=*)
      SIM_DURATION="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

# Function to download NS-3
download_ns3() {
  echo "Downloading NS-3 $NS3_VERSION..."
  if ! wget -q --show-progress -O "$NS3_ARCHIVE" "$NS3_URL"; then
    echo "Failed to download NS-3"
    exit 1
  fi
}

# Function to extract NS-3
extract_ns3() {
  echo "Extracting NS-3..."
  if ! tar -xf "$NS3_ARCHIVE" -C "$(dirname "$NS3_DIR")"; then
    echo "Failed to extract NS-3"
    exit 1
  fi
}

# Check if NS-3 exists; if not, download and extract it
if [ ! -d "$NS3_DIR" ]; then
  download_ns3
  extract_ns3
fi

# Create scratch directory if it doesn't exist
if [ ! -d "$NS3_DIR/scratch" ]; then
  mkdir -p "$NS3_DIR/scratch"
fi

# Copy simulation script to NS-3 scratch directory
echo "Copying p2pool-sim.cc to $NS3_DIR/scratch/"
cp "$SCRIPT_DIR/../src/p2pool-sim.cc" "$NS3_DIR/scratch/"

# Build NS-3 with the simulation
cd "$NS3_DIR" || exit 1
echo "Configuring NS-3..."

# Configure NS-3 (check if we need to use the old or new command style)
if [ -f "./waf" ]; then
  # Old style (NS-3 versions < 3.36)
  ./waf configure --disable-examples --disable-tests
  echo "Building simulation..."
  ./waf build
  
  # Run the simulation
  echo "Running simulation..."
  ./waf --run "scratch/p2pool-sim --nNodes=$NODES --latencyMean=$LATENCY_MEAN --latencyStd=$LATENCY_STD --shareMean=$SHARE_MEAN --shareStd=$SHARE_STD --simDuration=$SIM_DURATION"
else
  # New style (NS-3 versions >= 3.36)
  ./ns3 configure --disable-examples --disable-tests
  echo "Building simulation..."
  ./ns3 build scratch/p2pool-sim
  
  # Run the simulation
  echo "Running simulation..."
  ./ns3 run "scratch/p2pool-sim --nNodes=$NODES --latencyMean=$LATENCY_MEAN --latencyStd=$LATENCY_STD --shareMean=$SHARE_MEAN --shareStd=$SHARE_STD --simDuration=$SIM_DURATION"
fi
