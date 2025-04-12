param (
    [string[]]$args = @()
)

# Define NS-3 version and paths
$ns3Version = "3.44"
$ns3Dir = "$PSScriptRoot/../ns-allinone-$ns3Version/ns-$ns3Version"
$ns3Url = "https://www.nsnam.org/releases/ns-allinone-$ns3Version.tar.bz2"
$ns3Archive = "$PSScriptRoot/../ns-allinone-$ns3Version.tar.bz2"

# Function to download NS-3 with retries
function Download-NS3 {
    $maxRetries = 3
    $retryCount = 0
    $success = $false

    while (-not $success -and $retryCount -lt $maxRetries) {
        try {
            Write-Host "Attempting to download NS-3 $ns3Version (Attempt $($retryCount + 1)/$maxRetries)..."
            Invoke-WebRequest -Uri $ns3Url -OutFile $ns3Archive -ErrorAction Stop
            $success = $true
        }
        catch {
            $retryCount++
            Write-Host "Download failed: $_"
            if ($retryCount -lt $maxRetries) {
                Write-Host "Retrying in 5 seconds..."
                Start-Sleep -Seconds 5
            }
            else {
                Write-Error "Failed to download NS-3 after $maxRetries attempts."
                exit 1
            }
        }
    }
}

# Check if NS-3 is already present; if not, download and extract it
if (-not (Test-Path $ns3Dir)) {
    Download-NS3
    Write-Host "Extracting NS-3..."
    try {
        # Use 7z from PATH (installed via Chocolatey)
        7z x $ns3Archive -o"$PSScriptRoot/.." -y
        7z x "$PSScriptRoot/../ns-allinone-$ns3Version.tar" -o"$PSScriptRoot/.." -y
        Remove-Item $ns3Archive -ErrorAction SilentlyContinue
        Remove-Item "$PSScriptRoot/../ns-allinone-$ns3Version.tar" -ErrorAction SilentlyContinue
    }
    catch {
        Write-Error "Failed to extract NS-3: $_"
        exit 1
    }
}

# List extracted directories for debugging
Write-Host "Listing extracted directories:"
Get-ChildItem "$PSScriptRoot/.." | Format-Table -AutoSize

# Verify the scratch directory exists
if (-not (Test-Path "$ns3Dir/scratch")) {
    Write-Error "NS-3 scratch directory not found: $ns3Dir/scratch"
    exit 1
}

# Copy the simulation script to the NS-3 scratch directory
try {
    Write-Host "Copying p2pool-sim.cc to $ns3Dir/scratch/"
    Copy-Item "$PSScriptRoot/../src/p2pool-sim.cc" "$ns3Dir/scratch/" -Force -ErrorAction Stop
}
catch {
    Write-Error "Failed to copy simulation script: $_"
    exit 1
}

# Build NS-3 with CMake using Visual Studio 2022
Set-Location "$ns3Dir"
if (-not (Test-Path "build")) {
    New-Item -ItemType Directory -Name "build"
}
Set-Location "build"
try {
    Write-Host "Running CMake with verbose output..."
    # Use correct flags for NS-3 3.44, disable optional features
    cmake .. -G "Visual Studio 17 2022" -A x64 -DNS3_LOG=ON -DNS3_ASSERT=ON -DNS3_EXAMPLES=OFF -DNS3_TESTS=OFF -DNS3_PYTHON_BINDINGS=OFF -DNS3_GTK3=OFF -DNS3_MPI=OFF -DCMAKE_VERBOSE_MAKEFILE=ON
    Write-Host "Building NS-3 (p2pool-sim only)..."
    # Build only the scratch program to isolate issues
    cmake --build . --config Release --target p2pool-sim -- -maxcpucount > build.log 2>&1
}
catch {
    Write-Error "Failed to build NS-3: $_"
    if (Test-Path "build.log") {
        Write-Host "Build log contents:"
        Get-Content "build.log"
    }
    exit 1
}
finally {
    # Check if build directory contains expected output
    $exePath = ".\scratch\p2pool-sim\p2pool-sim.exe"
    if (-not (Test-Path $exePath)) {
        Write-Error "Build did not produce expected executable: $exePath"
        if (Test-Path "build.log") {
            Write-Host "Build log contents:"
            Get-Content "build.log"
        }
        exit 1
    }
}

# Run the simulation
Write-Host "Running simulation with args: $args"
try {
    & $exePath $args
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Simulation failed with exit code $LASTEXITCODE"
        exit 1
    }
}
catch {
    Write-Error "Failed to run simulation: $_"
    exit 1
}
