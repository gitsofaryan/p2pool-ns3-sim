# P2Poolv2 NS3 Simulation

This repository contains an NS3 simulation for P2Poolv2’s sharechain with uncles, designed to analyze scalability and performance. It models a P2P network of up to 10,000 nodes, simulating share production and latency, and reports metrics like uncle and orphan rates.

## Purpose
P2Poolv2 uses uncles to reduce orphan blocks, enhancing miner fairness. This simulation:
- Tests sharechain scalability under varying node counts and latencies.
- Measures uncle and orphan percentages to inform parameter tuning.
- Aligns with the Rust implementation at [pool2win/p2pool-v2](https://github.com/pool2win/p2pool-v2).

## Prerequisites
- **Windows** (for `run-sim.ps1`; Linux support planned).
- **CMake**: [Download](https://cmake.org/download/).
- **Python 3.6+**: [Download](https://www.python.org/downloads/).
- **Visual Studio 2019/2022**: Install with “Desktop development with C++” workload.
- **7-Zip**: [Download](https://www.7-zip.org/) for extracting NS3.

## Setup and Usage
### Local Execution
1. Clone this repository:
   ```bash
   git clone https://github.com/gitsofaryan/p2pool-ns3-sim.git
   cd p2pool-ns3-sim
