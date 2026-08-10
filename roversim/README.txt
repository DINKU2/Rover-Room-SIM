RoverTwin — Linux-ready bundle
==============================

Created from the Windows UE 5.3.2 project with build artifacts removed.

Contents
--------
RoverTwin/       Clean UE 5.3 project (Content, Config, uproject)
buildrover/      Source assets (FBX, rover URDF/OBJ) + Linux packager copy

Excluded (recreated automatically on Linux)
-------------------------------------------
Binaries/, Intermediate/, Saved/, DerivedDataCache/, Build/
Windows .bat files and MSVC config

Open in editor (Step 3 — when ready)
------------------------------------
/home/dinuk/UnrealEngine_5.3/Engine/Binaries/Linux/UnrealEditor \
  /home/dinuk/Desktop/RoverSIMUunreal-Linux/RoverTwin/RoverTwin.uproject

Package for Linux (Step 4 — when ready)
---------------------------------------
cd /home/dinuk/Desktop/RoverSIMUunreal-Linux/RoverTwin
./PackageRoverTwin_Linux.sh

Prerequisite check (Step 2 — run 2026-06-07)
----------------------------------------------
[PASS] UE 5.3.2 Linux editor: /home/dinuk/UnrealEngine_5.3
[PASS] RunUAT.sh and Linux Build.sh present
[PASS] Vulkan loader (vulkaninfo)
[PASS] NVIDIA GPU detected (vendor 0x10de, driver 1.4.329)
[PASS] clang 14.0.0
[PASS] build-essential, lld
[PASS] libgtk-3, libxrandr2, libxi6, libxinerama1, libxcursor1
[PASS] mesa-vulkan-drivers, libvulkan1

Startup map: /Game/Maps/MyRoom
Engine association: 5.3
