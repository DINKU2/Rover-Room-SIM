# NVIDIA PRIME + Vulkan settings for Unreal Engine on hybrid-GPU Linux.
# Source from launch scripts:  source "$(dirname "$0")/rover_nvidia_env.sh"

export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/nvidia_icd.json}"

# Wayland sessions often fail Vulkan window creation with PRIME laptops.
if [[ "${XDG_SESSION_TYPE:-}" == "wayland" && -z "${GDK_BACKEND:-}" ]]; then
  export GDK_BACKEND=x11
fi
