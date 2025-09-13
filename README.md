# CS Demo Processor

This program automates the process of downloading a Counter-Strike 2 demo, analyzing it, recording highlights of a specified player, and uploading the resulting video to YouTube. It runs as a continuous service with a web interface for queuing jobs, making it a complete, hands-free pipeline.

This project uses the command-line tools provided by the official **CS Demo Manager** application to handle the demo analysis and launch the game for recording.

## Installation Guide

This guide is designed to be as user-friendly as possible.


### Quick start (Windows)

### Step 1: Install Required Software

Before you begin, you must manually install the following programs:

1.  **CS Demo Manager**: Download and install the latest release from the [official CSDM GitHub page](https://github.com/akiver/cs-demo-manager/releases).

### Step 2: Download and Install This Project

1.  Run this in **PowerShell** (it will ask for Admin to install prerequisites):

```powershell
irm https://raw.githubusercontent.com/<you>/<repo>/main/bootstrap.ps1 | iex

```

What it does:

* Enables Windows long paths

* Installs 7-Zip CLI

* Downloads and extracts the project to C:\d2v

* Launches install.bat

If you prefer Git:

1. Install Git: winget install -e --id Git.Git

2. git config --system core.longpaths true

3. git clone https://github.com/<you>/<repo>.git C:\src\d2v
2.  **Run the Installer**: From the main project folder, double-click the `install.bat` file. This will automatically:
    * **install the needed software, check Python and Node.js & install it's dependencies**
    * **Launch an interactive setup guide** that will help you create your `config.ini` file.

### Step 3: Authorize YouTube

After the installer finishes, you need to authorize the application with Google.

1.  Open a terminal in the **`cs-demo-processor`** subfolder.
2.  Run the command: `python setup_youtube_auth.py`
3.  Follow the browser prompts to log in and grant permission.

## How to Run the Application

1.  **Run the Launcher**: From the main project folder, double-click the `run.bat` file.

This will automatically start the necessary background processes and open the web interface in your default browser at `http://localhost:5001`.




