
# P2Pool NS-3 Simulation

This repository contains a simulation of a P2Pool-like decentralized mining pool using the NS-3 network simulator. The simulation models nodes generating and sharing "shares" in a sharechain, tracking metrics such as total shares, uncles, and orphans. The code is written in C++ and leverages NS-3’s network simulation capabilities to mimic a distributed network environment.

## Overview

- **Purpose**: Simulate a P2Pool network to study share propagation, uncle inclusion, and orphan rates under various network conditions.
- **Language**: C++ with NS-3 framework.
- **Key Features**:
  - Custom `P2PoolApp` application for nodes to generate and broadcast shares.
  - `Sharechain` class to manage share validation and metrics.
  - Random mesh topology with configurable node count and latency.
  - Command-line arguments for customization (e.g., number of nodes, simulation duration).

## Directory Structure

```
P2POO.../ (or p2pool-ns3-sim/)
├── README.md              # This file
├── src/                   # Source code directory
│   └── p2pool-sim.cc      # Main simulation code
```

## Code Summary

The `p2pool-sim.cc` file implements a network simulation with the following components:

- **Dependencies**:
  - NS-3 modules: `core-module`, `network-module`, `internet-module`, `point-to-point-module`, `applications-module`, `random-variable-stream`.
  - C++ standard library: `<chrono>`, `<iomanip>`, `<map>`, `<random>`, `<sstream>`, `<string>`, `<vector>`.

- **Key Classes**:
  - **`Share`**: Represents a share with a hash, height, timestamp, parent hash, and uncles.
  - **`Sharechain`**: Manages shares, validates them, and tracks uncles and orphans.
  - **`P2PoolApp`**: A custom NS-3 application for nodes to generate, broadcast, and receive shares using UDP sockets.

- **Simulation Logic**:
  - Nodes create a random mesh topology, connecting to up to 4 peers.
  - Shares are generated at random intervals (normal distribution) and broadcast with simulated latency.
  - Metrics (total shares, uncles, orphans) are computed and printed at the end.

- **Command-Line Arguments**:
  - `--nNodes`: Number of nodes (default: 100).
  - `--latencyMean`: Mean latency in seconds (default: 0.1).
  - `--latencyStd`: Standard deviation of latency (default: 0.02).
  - `--shareMean`: Mean share production interval in seconds (default: 10.0).
  - `--shareStd`: Standard deviation of share production (default: 2.0).
  - `--simDuration`: Simulation duration in seconds (default: 3600.0).

- **Output**:
  - Printed to stdout: `Total Shares`, `Total Uncles` (with percentage), `Total Orphans` (with percentage). Redirect to a file (e.g., `simulation-results.txt`) using `> simulation-results.txt`.

## Prerequisites

To run the simulation locally, install the following dependencies based on your operating system:

### On Windows
- **Visual Studio 2022**: Community Edition with the Desktop Development with C++ workload.
- **CMake**: Version 3.10 or later (download from [cmake.org](https://cmake.org)).
- **7-Zip**: For extracting NS-3 archives (download from [7-zip.org](https://www.7-zip.org)).
- **Python**: Version 3.9 or later (download from [python.org](https://www.python.org)).
- **NS-3**: Version 3.44 (source code from [nsnam.org](https://www.nsnam.org)).

### On Linux (Alternative)
- **g++**: C++ compiler.
- **CMake**: Version 3.10 or later.
- **Python3**: Version 3.x.
- **Build Tools**: `build-essential`, `wget`.
- **NS-3**: Version 3.44.

## Installation and Setup

### On Windows

1. **Install Dependencies**:
   - Install Visual Studio 2022 and select the C++ workload during installation.
   - Install CMake and add it to your system PATH (e.g., `C:\Program Files\CMake\bin`).
   - Install 7-Zip and add it to your PATH (e.g., `C:\Program Files\7-Zip`).
   - Install Python 3.9 and ensure `python` is in your PATH (e.g., `C:\Python39` and `C:\Python39\Scripts`).

2. **Download NS-3**:
   - Open a Command Prompt or PowerShell.
   - Navigate to your project directory:
     ```cmd
     cd C:\Users\maila\Desktop\P2POO...
     ```
   - Since `wget` isn’t native to Windows, manually download `ns-allinone-3.44.tar.bz2` from [https://www.nsnam.org/releases/](https://www.nsnam.org/releases/) and place it in the directory.
   - Extract the archive:
     ```cmd
     7z x ns-allinone-3.44.tar.bz2
     7z x ns-allinone-3.44.tar
     ```

3. **Copy the Simulation Script**:
   - Move `src/p2pool-sim.cc` to the NS-3 scratch directory:
     ```cmd
     copy src\p2pool-sim.cc ns-allinone-3.44\ns-3.44\scratch\
     ```

4. **Build NS-3**:
   - Open a Visual Studio Developer Command Prompt (search for "Developer Command Prompt" in the Start menu).
   - Navigate to the NS-3 directory:
     ```cmd
     cd C:\Users\maila\Desktop\P2POO...\ns-allinone-3.44\ns-3.44
     ```
   - Create a build directory and configure with CMake:
     ```cmd
     mkdir build
     cd build
     cmake .. -G "Visual Studio 17 2022" -A x64 -DNS3_LOG=ON -DNS3_ASSERT=ON -DNS3_EXAMPLES=OFF -DNS3_TESTS=OFF -DNS3_PYTHON_BINDINGS=OFF -DNS3_GTK3=OFF -DNS3_MPI=OFF -DBoost_NO_BOOST_CMAKE=TRUE
     ```
   - Build only the `p2pool-sim` target:
     ```cmd
     cmake --build . --config Release --target p2pool-sim
     ```

5. **Run the Simulation**:
   - Execute the compiled executable with desired arguments:
     ```cmd
     cd C:\Users\maila\Desktop\P2POO...\ns-allinone-3.44\ns-3.44\build
     scratch\p2pool-sim\p2pool-sim.exe --nNodes=200 --simDuration=1800 > simulation-results.txt
     ```
   - Adjust arguments as needed (e.g., `--nNodes=50 --simDuration=300`).
   - Open `simulation-results.txt` to view the output.

### On Linux (Alternative)

1. **Install Dependencies**:
   - Open a terminal and run:
     ```bash
     sudo apt-get update
     sudo apt-get install -y g++ python3 python3-dev pkg-config sqlite3 cmake wget build-essential
     ```

2. **Download NS-3**:
   - Navigate to your project directory:
     ```bash
     cd ~/path/to/P2POO...
     ```
   - Download and extract NS-3:
     ```bash
     wget https://www.nsnam.org/releases/ns-allinone-3.44.tar.bz2
     tar -xjf ns-allinone-3.44.tar.bz2
     rm ns-allinone-3.44.tar.bz2
     ```

3. **Copy the Simulation Script**:
   - Move `src/p2pool-sim.cc` to the NS-3 scratch directory:
     ```bash
     cp src/p2pool-sim.cc ns-allinone-3.44/ns-3.44/scratch/
     ```

4. **Build NS-3**:
   - Navigate to the NS-3 directory:
     ```bash
     cd ns-allinone-3.44/ns-3.44
     mkdir -p build
     cd build
     cmake .. -DNS3_LOG=ON -DNS3_ASSERT=ON -DNS3_EXAMPLES=OFF -DNS3_TESTS=OFF -DNS3_PYTHON_BINDINGS=OFF -DNS3_GTK3=OFF -DNS3_MPI=OFF
     make -j$(nproc) p2pool-sim
     ```

5. **Run the Simulation**:
   - Execute the compiled executable:
     ```bash
     cd ns-allinone-3.44/ns-3.44/build
     ./bin/p2pool-sim --nNodes=200 --simDuration=1800 > simulation-results.txt
     ```
   - Adjust arguments as needed.
   - View results in `simulation-results.txt`.
