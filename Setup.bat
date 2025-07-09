@echo off
::echo DEBUG: Starting script
:check_hf_token
::echo DEBUG: Entered check_hf_token
setlocal EnableDelayedExpansion
::echo DEBUG: After setlocal
echo.
::echo DEBUG: Checking HF_TOKEN
::echo DEBUG: About to evaluate HF_TOKEN
set "HF_TOKEN_CHECK=%HF_TOKEN%"
::echo DEBUG: HF_TOKEN value = %HF_TOKEN_CHECK%
if "%HF_TOKEN%"=="" (
    ::echo DEBUG: HF_TOKEN is not defined
    :enter_token_loop
    echo A Huggingface token is not set. A Huggingface token is required for this blueprint, 
	echo provide your Huggingface token to continue the installation.
	echo.
    set /p "hf_token_input=Enter your Huggingface token (starts with 'hf_') or type 'n' to skip: "
    ::echo DEBUG: User input = !hf_token_input!
    set "hf_token_input_lower=!hf_token_input!"
    for %%i in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do set "hf_token_input_lower=!hf_token_input_lower:%%i=%%i!"
    ::echo DEBUG: Lowercase input = !hf_token_input_lower!
    if /i "!hf_token_input_lower!"=="n" (
        echo Skipping Huggingface token entry.
        echo Huggingface token required for blueprint setup.
        goto :user_terminated
    ) else if "!hf_token_input:~0,3!"=="hf_" (
        echo Setting HF_TOKEN...
        setx HF_TOKEN "!hf_token_input!"
        echo HF_TOKEN set. 
        ::echo DEBUG: Token set, going to prompt_continue
        goto :prompt_continue
    ) else (
        echo Invalid token format. Token must start with "hf_" or you must type 'n' to skip.
        ::echo DEBUG: Invalid input, looping back
        goto :enter_token_loop
    )
) else (
    ::echo DEBUG: HF_TOKEN
	goto :prompt_continue
)

:user_terminated
echo Installation terminated...
goto :END

:prompt_continue
echo.
echo This blueprint will install the following third party software:
echo     *  Blender 4.2 LTS - license - https://www.blender.org/about/license/
echo     *  MICROSOFT VISUAL C++ 2015 - 2022 RUNTIME - license - https://visualstudio.microsoft.com/license-terms/vs2022-cruntime/
echo     *  MICROSOFT VISUAL STUDIO 2022 - BUILD TOOLS - license - https://visualstudio.microsoft.com/license-terms/vs2022-ga-diagnosticbuildtools/
echo By installing this blueprint you accept the license agreements for the third party software shown above.
set "choice="
set /p "choice=Do you want to continue (y/n)? "
:: Trim and validate input
if not defined choice (
    echo Input was empty. Please enter 'y' or 'n'.
    goto :prompt_continue
)
:: Remove leading/trailing spaces
for /f "tokens=*" %%i in ("%choice%") do set "choice=%%i"
:: Convert to lowercase using simpler method
set "choice_lower=%choice%"
set "choice_lower=%choice_lower:Y=y%"
set "choice_lower=%choice_lower:N=n%"

:: Debug output
echo DEBUG: choice=%choice%, choice_lower=%choice_lower%

if /i "%choice_lower%"=="y" (
    echo Continuing...
    goto :BatchGotAdmin
) else if /i "%choice_lower%"=="n" (
    echo Exiting...
    goto :end
) else (
    echo Invalid input. Please enter 'y' or 'n'.
    goto :prompt_continue
)

:BatchGotAdmin
::-------------------------------------
REM  --> Check for permissions
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

REM --> If error flag set, we do not have admin.
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    goto UACPrompt
) else (
    goto gotAdmin
)

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
    :: Set the current directory to the script's directory
    pushd "%~dp0"
    echo Running with administrator privileges.
    
    :: Your commands go here
    :: The original notepad.exe command is here for context from the initial request
    :: notepad.exe
    
    setlocal EnableDelayedExpansion

    set "distro_name=NVIDIA-Workbench"

    echo Checking for WSL distribution "%distro_name%"...
    wsl -d %distro_name% echo OK >nul 2>&2
    set "distro_exists=!errorlevel!" :: Use !errorlevel! for delayed expansion

    if !distro_exists! equ 0 (
        echo "%distro_name%" found.
        echo Checking if Podman is installed in "%distro_name%"...
        wsl -d %distro_name% podman --version >nul 2>&2
        set "podman_installed=!errorlevel!" :: Use !errorlevel! for delayed expansion
        if !podman_installed! equ 0 (
            echo Podman is installed in "%distro_name%"
            goto :WSL_Ready
        ) else (
            echo Podman is NOT installed in "%distro_name%"
            echo AI Workbench is installed, but not fully configured for this blueprint.
            echo Please open NVIDIA AI Workbench and configure Podman before re-running the blueprint installer.
            goto :WSL_Not_Ready
        )
    ) else (
        echo "%distro_name%" was not found...
        echo Please download and complete the NIMSetup installation, a restart will be required,
        echo then re-run the blueprint installer.
        echo Download link: https://assets.ngc.nvidia.com/products/api-catalog/rtx/NIM_Prerequisites_Installer_03052025.zip
        goto :WSL_Not_Ready
    )

    :WSL_Not_Ready
    echo.
    echo Script completed with prerequisites not fully met.
    pause
    exit /b 1

    :WSL_Ready
    echo NVIDIA-Workbench is properly configured for this blueprint

    set "base_dir=%cd%"
    set "comfyui_install_dir=.\ComfyUI_windows_portable\"


    REM if no arguments are present or we have searched all arguments without finding one we want to act on, go to the comfyui install step
    IF "%~1"=="" (
        GOTO CheckExistingComfyInstall
    )

    :ProcessArg
    REM if no arguments are present or we have searched all arguments without finding one we want to act on, go to the comfyui install step
    if "%~1"=="" goto :CheckExistingComfyInstall

    IF /I "%1"=="-i" (
        ECHO Custom ComfyUI Path provided:
        IF EXIST "%2" (
            IF "%2:~-1%" NEQ "\" (
                set "comfyui_install_dir=%2\"
            ) ELSE (
                set "comfyui_install_dir=%2"
            )
            ECHO %comfyui_install_dir%
            SHIFT
        ) ELSE (
            ECHO "An existing directory MUST be provided when using the -i command line option. Install will exit."
            GOTO END
        )
    )

    IF /I "%1"=="--installFolder" (
        ECHO Custom ComfyUI Path provided:
        IF EXIST "%2" (
            IF "%2:~-1%" NEQ "\" (
                set "comfyui_install_dir=%2\"
            ) ELSE (
                set "comfyui_install_dir=%2"
            )
            ECHO %comfyui_install_dir%
            SHIFT
        ) ELSE (
            ECHO "An existing directory MUST be provided when using the -i command line option. Install will exit."
            GOTO END
        )
    )
    shift
    GOTO ProcessArg

    :SetManifest
    SET manifestFile=%1
    SET "customManifest=True"

    :CheckExistingComfyInstall
    REM Check to see if this is a default or previous user install with an existing ComfyUI installation
    IF EXIST %comfyui_install_dir%comfyui (
        GOTO GetUserInput
    )

    REM Check to see if this is a custom location install with an existing ComfyUI installation
    IF EXIST %comfyui_install_dir%ComfyUI_windows_portable\comfyui (
        SET "comfyui_install_dir=%comfyui_install_dir%ComfyUI_windows_portable\"
        GOTO GetUserInput
    )

    REM If no exist install is found install
    GOTO StartInstall


    :GetUserInput
    REM Prompt the user to decide how to proceed
    ECHO An existing ComfyUI installation was found in this directory. How would you like to proceed?
    ECHO 1. Resume Installation 
    ECHO 0. Exit
        
    SET /P choice="Enter your choice (1 or 0): "
    ECHO Option %choice% was selected
    IF "%choice%"=="1" (
        ECHO Installing component files only
        GOTO InstallGit
    ) ELSE IF "%choice%"=="0" (
        GOTO END
    ) ELSE (
        ECHO Invalid Selection!!!!
        ECHO Please select a valid option...
        GOTO CheckExistingComfyInstall
    )   

    :StartInstall
    ECHO Download ComfyUI
    curl -OL https://github.com/comfyanonymous/ComfyUI/releases/latest/download/ComfyUI_windows_portable_nvidia.7z

    REM I've had issues with the curl command failing, so check and bail out if it has
    IF %ERRORLEVEL% NEQ 0 (
        ECHO Problem with file download, try again
        EXIT
    ) ELSE (
        ECHO Extract ComfyUI
        IF "%comfyui_install_dir%"==".\ComfyUI_windows_portable\" (
            tar -xvf .\ComfyUI_windows_portable_nvidia.7z
                
        ) ELSE (
            mkdir %comfyui_install_dir% 2>nul
            pushd %comfyui_install_dir%
            tar -xvf ..\ComfyUI_windows_portable_nvidia.7z
            popd
            SET "comfyui_install_dir=%comfyui_install_dir%\ComfyUI_windows_portable\"
        )
        echo The current directory is: %CD%
        
        GOTO InstallGit
    )

    :InstallGit

    :: Check if git.exe is in the system PATH
    where git.exe >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        echo Git is already installed and found in PATH.
        goto :InstallPythonPackages
    )

    :: Git not found in PATH, attempt to install using winget
    echo Git not found in PATH. Installing Git...
    winget install --id Git.Git --silent --disable-interactivity
    if %ERRORLEVEL% neq 0 (
        echo Failed to install Git using winget.
        exit /b 1
    )

    :: Check if git.exe exists in the default location
    set "GIT_DEFAULT_PATH=%ProgramFiles%\Git\cmd\git.exe"
    if exist "%GIT_DEFAULT_PATH%" (
        echo Git found at %GIT_DEFAULT_PATH%.
        :: Add Git path to the current session's PATH
        set "PATH=%PATH%;%ProgramFiles%\Git\cmd"
        echo Added %ProgramFiles%\Git\cmd to the current PATH.
    ) else (
        echo Git was installed but not found at %GIT_DEFAULT_PATH%.
        exit /b 1
    )

    :InstallPythonPackages
    REM Get the python packages that the install script needs
    ECHO Install the Python Dependencies
    ECHO "%comfyui_install_dir%python_embeded\python.exe" -m pip install --no-cache-dir requests gitpython py7zr huggingface-hub validators
    "%comfyui_install_dir%python_embeded\python.exe" -s -m pip install --upgrade pip
    "%comfyui_install_dir%python_embeded\python.exe" -m pip install --no-cache-dir requests gitpython huggingface-hub validators pynvml


    REM Run the install script
    ECHO Download the Rest of the content

    :: This is the corrected line to ensure the new cmd window starts in the script's directory
    ECHO "%comfyui_install_dir%python_embeded\python.exe" -s .\installmill.py %* --baseFolder "%base_dir%" --installFolder "%comfyui_install_dir%"
    start cmd /k "pushd "%~dp0" && "%comfyui_install_dir%python_embeded\python.exe" -s .\installmill.py %* --baseFolder "%base_dir%" --installFolder "%comfyui_install_dir%""


    :END
    pause