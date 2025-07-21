import requests
import os
import subprocess
import hashlib
import sys
import ctypes
import time
import json
import argparse
from typing import List, Optional, Dict, Any
from pathlib import Path

def is_admin() -> bool:
    """Check if the script is running with administrator privileges."""
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except Exception:
        return False

def calculate_sha256(file_path: str) -> str:
    """Calculate SHA256 hash of a file."""
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

def download_file(url: str, filename: str) -> bool:
    """Download file from URL to specified filename."""
    print(f"Downloading {filename} from {url}...")
    try:
        response = requests.get(url, stream=True)
        if response.status_code == 200:
            with open(filename, "wb") as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
            print(f"Download completed: {filename}")
            return True
        else:
            print(f"Failed to download. HTTP Status: {response.status_code}")
            return False
    except Exception as e:
        print(f"Download error: {e}")
        return False

def verify_download(filename: str, expected_sha256: Optional[str] = None) -> bool:
    """Verify the downloaded file exists and optionally check its SHA256 hash."""
    if not os.path.exists(filename):
        print(f"File {filename} does not exist.")
        return False
    
    if expected_sha256:
        calculated_sha256 = calculate_sha256(filename)
        if calculated_sha256.lower() == expected_sha256.lower():
            print("SHA256 verification successful.")
            return True
        else:
            print(f"SHA256 verification failed. Expected: {expected_sha256}, Got: {calculated_sha256}")
            return False
    else:
        print("No SHA256 hash provided for verification. Skipping hash check.")
        return True

def run_installer(filename: str, install_args: List[str]) -> bool:
    """Run the installer with specified arguments."""
    command = [filename] + install_args
    print(f"Running installer: {' '.join(command)}")
    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True)
        print("Installation completed successfully.")
        print(result.stdout)
        return True
    except subprocess.CalledProcessError as e:
        print(f"Installation failed: {e}")
        print(e.stderr)
        return False
    except Exception as e:
        print(f"Error running installer: {e}")
        return False

def install_software(
    url: str,
    filename: str,
    install_args: List[str],
    expected_sha256: Optional[str] = None
) -> bool:
    """Download, verify, and install software."""
    # Step 1: Download the file
    if not download_file(url, filename):
        print("Download failure.")
        return False
    
    # Step 2: Verify the download
    if not verify_download(filename, expected_sha256):
        print("Verification failure.")
        return False
    
    # Step 3: Run the installer
    if not run_installer(filename, install_args):
        print("Installation failure.")
        return False
    
    print(f"Installation of {filename} completed successfully.")
    return True

def run_elevated(configs: List[Dict[str, Any]], result_file: str) -> None:
    """Run the installation process in elevated mode and write results to a file."""
    if not is_admin():
        print("Error: Elevated mode requested but script is not running as admin.")
        print("Please ensure you click 'Yes' on the UAC prompt or run the script as an administrator.")
        sys.exit(1)
    
    results = []
    all_success = True
    
    for config in configs:
        print(f"\nProcessing installation for {config['filename']}...")
        success = install_software(
            url=config["url"],
            filename=config["filename"],
            install_args=config["install_args"],
            expected_sha256=config["expected_sha256"]
        )
        results.append({
            "filename": config["filename"],
            "success": success
        })
        if not success:
            all_success = False
    
    # Write results to the temporary file
    try:
        with open(result_file, "w") as f:
            json.dump({"all_success": all_success, "results": results}, f)
    except Exception as e:
        print(f"Failed to write results to {result_file}: {e}")
        sys.exit(1)
    
    print("\nElevated installation process completed.")
    sys.exit(0 if all_success else 1)

def main():
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description="Install software with optional elevation.")
    parser.add_argument("--elevated", action="store_true", help="Run in elevated mode")
    parser.add_argument("--result-file", type=str, help="File to store elevated results")
    args = parser.parse_args()

    # List of configurations for multiple installations
    configs: List[Dict[str, Any]] = [
        {
            "url": "https://aka.ms/vs/17/release/vs_BuildTools.exe",
            "filename": "vs_BuildTools.exe",
            "install_args": [
                "--norestart",
                "--passive",
                "--add", "Microsoft.VisualStudio.Workload.VCTools",
                "--includeRecommended"
            ],
            "expected_sha256": None  # Replace with actual hash if known
        },
        {
            "url": "https://developer.download.nvidia.com/compute/cuda/12.9.1/network_installers/cuda_12.9.1_windows_network.exe",
            "filename": "cuda_12.9.1_windows_network.exe",
            "install_args": [
                "-s",
                "nvcc_12.9",
                "cudart_12.9"
            ],
            "expected_sha256": None  # Replace with actual hash if known
        }
    ]

    if args.elevated:
        # Running in elevated mode
        run_elevated(configs, args.result_file)
    
    # Non-elevated mode: check if elevation is needed
    if not is_admin():
        print("This script requires administrator privileges for installation. A UAC prompt will appear.")
        print("Please click 'Yes' to grant admin privileges.")
        result_file = os.path.join(os.getenv("TEMP", "."), f"install_results_{os.getpid()}.json")
        log_file = os.path.join(os.getenv("TEMP", "."), f"install_log_{os.getpid()}.txt")
        
        try:
            # Launch elevated instance using ShellExecuteW for UAC prompt
            cmd = [sys.executable, sys.argv[0], "--elevated", "--result-file", result_file]
            process = subprocess.Popen(
                cmd,
                stdout=open(log_file, "w"),
                stderr=subprocess.STDOUT,
                text=True,
                shell=True,  # Use shell to ensure UAC prompt is triggered
                creationflags=subprocess.CREATE_NEW_CONSOLE  # Ensure new console for visibility
            )
            
            # Wait for the process with a timeout
            timeout_seconds = 300
            print(f"Waiting for elevated process to complete (timeout: {timeout_seconds} seconds)...")
            try:
                process.wait(timeout=timeout_seconds)
            except subprocess.TimeoutExpired:
                print("Error: Elevated process did not complete within the timeout period.")
                process.terminate()
                sys.exit(1)
            
            # Check the process exit code
            if process.returncode != 0:
                print(f"Error: Elevated process failed with exit code {process.returncode}.")
                try:
                    with open(log_file, "r") as f:
                        log_content = f.read()
                    print(f"Elevated process output:\n{log_content}")
                except Exception as e:
                    print(f"Could not read log file {log_file}: {e}")
                print("Possible causes: UAC prompt was canceled, or the account lacks admin privileges.")
                print("Please run the script as an administrator or ensure you click 'Yes' on the UAC prompt.")
                sys.exit(1)
            
            # Read results from the temporary file
            try:
                if not os.path.exists(result_file):
                    print(f"Error: Results file {result_file} was not created.")
                    print("The UAC prompt may have been canceled, or the elevated process failed to start.")
                    print("Please ensure you click 'Yes' on the UAC prompt and have admin privileges.")
                    sys.exit(1)
                
                with open(result_file, "r") as f:
                    results = json.load(f)
                all_success = results["all_success"]
                for result in results["results"]:
                    status = "succeeded" if result["success"] else "failed"
                    print(f"Installation of {result['filename']} {status}.")
                
                # Clean up temporary files
                for file_path in [result_file, log_file]:
                    try:
                        if os.path.exists(file_path):
                            os.remove(file_path)
                    except Exception as e:
                        print(f"Warning: Failed to delete temporary file {file_path}: {e}")
                
                if not all_success:
                    print("\nSome installations failed.")
                    sys.exit(1)
                
                print("\nAll installations completed successfully.")
                print("Resuming non-elevated tasks (if any)...")
                # Add any additional non-elevated tasks here
                
            except Exception as e:
                print(f"Failed to read results from {result_file}: {e}")
                sys.exit(1)
        
        except subprocess.SubprocessError as e:
            print(f"Failed to launch elevated process: {e}")
            print("Please ensure you have admin privileges and try again.")
            sys.exit(1)
        except Exception as e:
            print(f"Error launching elevated process: {e}")
            sys.exit(1)
    else:
        # Already running as admin, process directly
        results = []
        all_success = True
        for config in configs:
            print(f"\nProcessing installation for {config['filename']}...")
            success = install_software(
                url=config["url"],
                filename=config["filename"],
                install_args=config["install_args"],
                expected_sha256=config["expected_sha256"]
            )
            results.append({
                "filename": config["filename"],
                "success": success
            })
            if not success:
                all_success = False
        
        if all_success:
            print("\nAll installations completed successfully.")
        else:
            print("\nSome installations failed.")
            sys.exit(1)

if __name__ == "__main__":
    main()