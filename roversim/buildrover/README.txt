RoverTwin portable bundle
=========================

Copy this entire "buildrover" folder to another PC or drive.

Contents
--------
RoverTwin/       Unreal Engine 5.3 project (open, edit, repackage)
SourceAssets/    Original FBX, textures, rover OBJ/URDF (re-import if needed)
Windows/         Ready-to-run Windows game (no Unreal install required)
BuildConfiguration.xml.example
                 Copy to your UnrealBuildTool folder on Windows (see below)

Run the game on Windows (no editor needed)
------------------------------------------
Double-click:  Windows\RoverTwin.exe

Keep the whole Windows\ folder together with its RoverTwin\ subfolder.

Edit or rebuild the project
---------------------------
Requirements:
  - Unreal Engine 5.3 (same major version)
  - Windows: Visual Studio 2022 Build Tools with MSVC 14.38.33130
  - Linux:   UE 5.3 Linux toolchain (install via Epic Launcher / source build)

Windows - open editor:
  1. Install UE 5.3 and MSVC 14.38 (run RoverTwin\InstallMSVC1438.bat if needed)
  2. Copy BuildConfiguration.xml.example to:
       %APPDATA%\Unreal Engine\UnrealBuildTool\BuildConfiguration.xml
  3. Run RoverTwin\OpenRoverTwin.bat

Windows - repackage game:
  1. Close the editor
  2. Run RoverTwin\PackageRoverTwin.bat
  3. Output goes to buildrover\Windows\

Linux - package (on a Linux machine with UE 5.3):
  1. Copy RoverTwin/ to the Linux box
  2. chmod +x PackageRoverTwin_Linux.sh
  3. Edit UE_ROOT inside the script if your engine path differs
  4. Run ./PackageRoverTwin_Linux.sh

Notes
-----
- Do not copy Binaries/, Intermediate/, Saved/, or DerivedDataCache/ from a dev
  machine; they are recreated automatically and bloat the folder.
- Startup map: /Game/Maps/MyRoom
- Engine association in RoverTwin.uproject: 5.3
