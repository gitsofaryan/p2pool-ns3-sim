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
Get-ChildItem "$PSScriptRoot/.." -Directory | Format-Table -AutoSize

# Verify the scratch directory exists
if (-not (Test-Path "$ns3Dir/scratch")) {
    Write-Host "Creating scratch directory"
    New-Item -ItemType Directory -Path "$ns3Dir/scratch" -Force
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
    # Create a minimal CMake option set, disabling optional features that might cause issues
    cmake .. -G "Visual Studio 17 2022" -A x64 `
        -DNS3_EXAMPLES=OFF `
        -DNS3_TESTS=OFF `
        -DNS3_PYTHON_BINDINGS=OFF `
        -DNS3_GTK3=OFF `
        -DNS3_MPI=OFF `
        -DCMAKE_BUILD_TYPE=Release
    
    Write-Host "Building NS-3 (p2pool-sim only)..."
    # Build only the scratch program with better verbosity
    cmake --build . --config Release --target scratch/p2pool-sim -- -maxcpucount:4 -verbosity:normal | Tee-Object -FilePath build.log
}
catch {
    Write-Error "Failed to build NS-3: $_"
    if (Test-Path "build.log") {
        Write-Host "Build log contents:"
        Get-Content "build.log"
    }
    exit 1
}

# Locate the executable
$exePath = $null
$possibleExePaths = @(
    ".\ns3.44-p2pool-sim-release.exe",
    ".\scratch\p2pool-sim.exe",
    ".\scratch\p2pool-sim\p2pool-sim.exe",
    ".\scratch\Release\p2pool-sim.exe"
)

foreach ($path in $possibleExePaths) {
    if (Test-Path $path) {
        $exePath = $path
        Write-Host "Found executable at: $exePath"
        break
    }
}

if (-not $exePath) {
    Write-Error "Could not find built executable. Searching for any .exe files:"
    Get-ChildItem -Path "." -Recurse -Filter "*.exe" | ForEach-Object { Write-Host $_.FullName }
    exit 1
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
