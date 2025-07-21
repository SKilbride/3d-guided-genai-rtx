import os
import subprocess
import urllib.request

# URL for MS Build Tools
url = "https://aka.ms/vs/17/release/vs_BuildTools.exe"
# Destination path for the downloaded file
dest_path = "vs_BuildTools.exe"

def download_build_tools():
    print("Downloading MS Build Tools...")
    try:
        urllib.request.urlretrieve(url, dest_path)
        print("Download completed successfully.")
    except Exception as e:
        print(f"Error downloading file: {e}")
        exit(1)

def install_build_tools():
    print("Starting MS Build Tools installation...")
    print("Please note: This process may take several minutes or more depending on your download speed.")
    try:
        # Run the installer with specified arguments
        subprocess.run([
            dest_path,
            "--norestart",
            "--passive",
            "--add", "Microsoft.VisualStudio.Workload.VCTools",
            "--includeRecommended"
        ], check=True)
        print("Installation completed successfully.")
    except subprocess.CalledProcessError as e:
        print(f"Error during installation: {e}")
        exit(1)
    finally:
        # Clean up the downloaded installer
        if os.path.exists(dest_path):
            os.remove(dest_path)
            print("Cleaned up downloaded installer.")

if __name__ == "__main__":
    download_build_tools()
    install_build_tools()