# CS Demo Processor

This program automates the process of downloading a Counter-Strike 2 demo, analyzing it, recording highlights of a specified player, and uploading the resulting video to YouTube. It runs as a continuous service with a web interface for queuing jobs, making it a complete, hands-free pipeline.

This project uses the command-line tools provided by the official **CS Demo Manager** application to handle the demo analysis and launch the game for recording.

## Installation Guide

This guide is designed to be as user-friendly as possible.

### Step 1: Install Required Software

Before you begin, you must manually install the following programs:

1.  **CS Demo Manager**: Download and install the latest release from the [official CSDM GitHub page](https://github.com/akiver/cs-demo-manager/releases).
    * **IMPORTANT**: After installing, run CS Demo Manager at least once. It will guide you through setting up its required PostgreSQL database. This step must be completed before you proceed.
2.  **OBS Studio**: Install from [obsproject.com](https://obsproject.com/).

### Step 2: Download and Install This Project

1.  **Download**: Download this project as a ZIP file and extract it to a permanent location on your computer (e.g., `C:\CS-Demo-Processor`).
2.  **Run the Installer**: From the main project folder, double-click the `install.bat` file. This will automatically:
    * **Check for Python and Node.js**: If they are not installed or not in your system's PATH, the script will stop and provide you with a download link.
    * **Install all dependencies** for this project.
    * **Launch an interactive setup guide** that will help you create your `config.ini` file.

### Step 3: Authorize YouTube

After the installer finishes, you need to authorize the application with Google.

1.  Open a terminal in the **`cs-demo-processor`** subfolder.
2.  Run the command: `python setup_youtube_auth.py`
3.  Follow the browser prompts to log in and grant permission.

## How to Run the Application

1.  **Start OBS Studio**: Open OBS and leave it running in the background. Make sure it's configured according to the setup guide (Game Capture source, correct output folder, etc.).
2.  **Run the Launcher**: From the main project folder, double-click the `run.bat` file.

This will automatically start the necessary background processes and open the web interface in your default browser at `http://localhost:5001`.