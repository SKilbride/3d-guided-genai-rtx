import sys
import subprocess

# The list of requirements hardcoded from your text file
requirements = [
    "torch",
    "importlib_metadata",
    "huggingface_hub",
    "scipy",
    "opencv-python>=4.7.0.72",
    "filelock",
    "numpy",
    "Pillow",
    "einops",
    "torchvision",
    "pyyaml",
    "scikit-image",
    "python-dateutil",
    "mediapipe",
    "fvcore",
    "yapf",
    "omegaconf",
    "ftfy",
    "addict",
    "yacs",
    "trimesh[easy]",
    "albumentations",
    "scikit-learn",
    "matplotlib"
]

print(f"Starting installation of {len(requirements)} packages...")

for package in requirements:
    try:
        print(f"--------------------------------------------------")
        print(f"Installing: {package}")
        # Attempt to install the individual package
        subprocess.check_call([sys.executable, '-m', 'pip', 'install', package])
    except subprocess.CalledProcessError:
        # If installation fails (e.g. mediapipe), print error and continue loop
        print(f"!! ERROR: Failed to install '{package}'. Skipping to next...")
    except Exception as e:
        print(f"!! An unexpected error occurred with '{package}': {e}")

print("--------------------------------------------------")
print("Batch installation complete.")