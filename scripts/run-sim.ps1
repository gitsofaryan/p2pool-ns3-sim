# scripts/run-sim.ps1
param (
    [string[]]$args = @()
)

$ns3Version = "3.44"
$ns3Dir = "$PSScriptRoot/../ns-allinone-$ns3Version/ns-allinone-$ns3Version/ns-$ns3Version"
$ns3Url = "https://www.nsnam.org/releases/ns-allinone-$ns3Version.tar.bz2"
$ns3Archive = "$PSScriptRoot/../ns-allinone-$ns3Version.tar.bz2"

# Function to download NS3 with retries
function Download-NS3 {
    $maxRetries = 3
    $retryCount = 0
    $success = $false

    while (-not $success -and $retryCount -lt $maxRetries) {
        try {
            Write-Host "Attempting to download NS3 $ns3Version (Attempt $($retryCount + 1)/$maxRetries)..."
            Invoke-WebRequest -Uri $ns3Url -OutFile $ns3Archive -ErrorAction Stop
            $success = $true
        }
        catch {
            $retryCount++
            Write-Host "Download failed: $_"
            if ($retryCount -lt $maxRetries) {
                Write-Host "Retrying in 5 seconds..."
                Start-Sleep -Seconds 5
            } else {
                Write-Error "Failed to download NS3 after $maxRetries attempts."
                exit 1
            }
        }
    }
}

# Download NS3 if not already present
if (-not (Test-Path $ns3Dir)) {
    Download-NS3
    Write-Host "Extracting NS3..."
try {
    & "C:\Program Files\7-Zip\7z.exe" x $ns3Archive -o"$PSScriptRoot/.." -y
    & "C:\Program Files\7-Zip\7z.exe" x "$PSScriptRoot/../ns-allinone-$ns3Version.tar" -o"$PSScriptRoot/.." -y
    Remove-Item $ns3Archive -ErrorAction SilentlyContinue
    Remove-Item "$PSScriptRoot/../ns-allinone-$ns3Version.tar" -ErrorAction SilentlyContinue
}
catch {
    Write-Error "Failed to extract NS3: $_"
    exit 1
}

Write-Host "Listing extracted directories:"
Get-ChildItem "$PSScriptRoot/.."

if (-not (Test-Path "$ns3Dir/scratch")) {
    Write-Error "NS-3 scratch directory not found: $ns3Dir/scratch"
    exit 1
}

# Copy simulation script to NS3 scratch directory
try {
    Copy-Item "$PSScriptRoot/../src/p2pool-sim.cc" "$ns3Dir/scratch/" -Force -ErrorAction Stop
}
catch {
    Write-Error "Failed to copy simulation script: $_"
    exit 1
}
# Build NS3 with CMake
cd "$ns3Dir"
if (-not (Test-Path "build")) {
    mkdir build
}
cd build
try {
    cmake .. -G "Visual Studio 16 2019" -A x64  # Adjust for Visual Studio version
    cmake --build . --config Release
}
catch {
    Write-Error "Failed to build NS3: $_"
    exit 1
}

# Run the simulation
cd "scratch/p2pool-sim"
Write-Host "Running simulation with args: $args"
try {
    .\p2pool-sim.exe $args
}
catch {
    Write-Error "Simulation failed: $_"
    exit 1
}
