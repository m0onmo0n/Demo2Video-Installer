> [!IMPORTANT]
> EVERYTHING is currently broken cuz valve

# CS Demo Processor

Automates the workflow of downloading a Counter-Strike 2 demo, analyzing it, recording highlights of a specified player, and uploading the result to YouTube. It runs a local web UI so you can queue jobs and let it churn in the background.

This repo bundles the **CS Demo Manager (CSDM)** CLI via a fork made by Norton; you most likely don’t need the official CSDM GUI installed to use this project as this project also uses a remote DB hosted by our lovely Patty.
IF you wish to use your own DB, you can change the credentials in the config.ini file after the fact and create your own DB using postgres.


pre-requisites to use this project are steam and cs2, everything else gets installed.

to use the "one liners" down below you need to have winget installed, this comes with all windows installs after win 10 2004.

---

## Installation (Windows)

Designed to be one-command friendly. Pick **one** option below.

### Option A — install to `C:\d2v` (recommended)
> Short path avoids Windows path-length issues.
```powershell
Start-Process powershell -Verb RunAs -ArgumentList @(
  '-NoExit','-NoProfile','-ExecutionPolicy','Bypass',
  '-Command', '$u=''https://raw.githubusercontent.com/m0onmo0n/Demo2Video-Installer/main/bootstrap.ps1''; $p=Join-Path $env:TEMP ''d2v_bootstrap.ps1''; curl.exe -L $u -o $p; & $p'
)

```

### Option B — install under your current folder (creates `.\d2v`)
```powershell
Start-Process powershell -Verb RunAs -ArgumentList @(
  '-NoExit','-NoProfile','-ExecutionPolicy','Bypass',
  '-Command', '$here=(Resolve-Path .).Path; $dest=Join-Path $here ''d2v''; $u=''https://raw.githubusercontent.com/m0onmo0n/Demo2Video-Installer/main/bootstrap.ps1''; $p=Join-Path $env:TEMP ''d2v_bootstrap.ps1''; curl.exe -L $u -o $p; & $p -DestRoot $dest'
)

```

**What the bootstrap does**
- Enables Windows **long paths** (if not already).
- Ensures **7-Zip** CLI is present (for long-path-safe extraction).
- Downloads and extracts this repo into `C:\d2v` (or `.\d2v` for Option B).
- Launches **`install.bat`**.

### During install
`install.bat` will:
- Install prerequisites (Python 3.13 + Launcher, NVM for Windows, Node.js LTS if needed, PostgreSQL, VS 2022 Build Tools C++ workload, OBS Studio).
- Install Python/Node dependencies.
- Run a short **interactive configuration** to produce `config.ini`.

> If a future update requires the official CSDM app, we’ll note it here. For now, the forked CLI in this repo is sufficient.

---

## Step 2 — Authorize YouTube (one-time)
From the `cs-demo-processor` folder:
```powershell
python setup_youtube_auth.py
```
Follow the browser prompts to grant access.

---

## How to Run

### One-click
Double-click **`run.bat`** (repo root). It:
- Resolves **Node/NVM** and **Python** for this window (no PATH drama).
- Starts the **CSDM dev server** and the **CS Demo Processor**.
- Launches **OBS** (if you saved its path on first run).
- Opens the web UI at **http://localhost:5001**.

### Manual (advanced)
- **CSDM dev server**
  ```powershell
  cd cs-demo-processor\csdm-fork
  nvm use 20.19.1
  npm ci
  node scripts/develop-cli.mjs
  ```
- **Processor + web server**
  ```powershell
  cd ..\..
  python main.py
  ```
- **OBS**
  - OBS ≥ 28 already includes WebSocket (Tools → WebSocket Server Settings).
  - Default port is **4455**. If you use a password, put it in `config.ini`.

---

## Configuration

### `config.ini`
The installer’s setup step creates it for you. Re-run anytime:
```powershell
cd cs-demo-processor
python setup.py
```
Ensure the `[Paths]` section is filled (e.g., output directory, ffmpeg path, OBS WebSocket port/password).

### Optional: environment keys
If you have API keys, you can add them to a `.env` in `csdm-fork` (or wherever your app expects them), but they’re **optional**. Without them, some external requests will be skipped or rate-limited.
- `STEAM_API_KEYS` — optional (comma-separated)
- `FACEIT_API_KEY` — optional

---

## Development notes

- Recommended Node: **20.19.1**.  
  The launcher will install/use this automatically if needed. If you want to pin it for developers, you may add a `.nvmrc` file under `cs-demo-processor\csdm-fork` containing:
  ```
  20.19.1
  ```

---

## Troubleshooting

**“Python/Node not recognized” after install**
- Close and reopen the terminal, or just use `run.bat` (it resolves both for the current window).
- Python: `py -3 --version` should work immediately (Python Launcher is installed).
- Node/NVM: `nvm use 20.19.1`. If NVM lives in unusual locations (e.g., `C:\nvm4w` with symlink `C:\nvm4w\nodejs`), `run.bat` detects those too.

**CSDM dev server errors about missing native modules**
- Force a rebuild of the native addon:
  ```powershell
  cd cs-demo-processor\csdm-fork\src\node\os\get-running-process-exit-code
  $env:GYP_MSVS_VERSION='2022'
  ..\..\..\node_modules\.bin\node-gyp.cmd rebuild --msvs_version=2022
  ```

**`npm ci` fails with libuv assertion or esbuild “spawn UNKNOWN”**
- Use Node **20.19.1**:
  ```powershell
  nvm use 20.19.1
  cmd /c rd /s /q node_modules
  npm cache clean --force
  npm ci
  npm rebuild esbuild --force
  ```
  Also ensure antivirus isn’t blocking `node_modules\esbuild\esbuild.exe`.

**Processor says `Configuration error: 'Paths'`**
- Run `python setup.py` again to regenerate `config.ini`. Fill all keys under `[Paths]` (output dir, ffmpeg, OBS settings).

**OBS WebSocket**
- OBS ≥ 28: built-in at Tools → WebSocket Server Settings (port **4455**).  
  No plugin needed. If using a password, put it in `config.ini`.

**Firewall prompts**
- On first run, allow Python (Flask) on `localhost:5001`.  
  OBS WebSocket on port 4455 should be allowed for local connections.

---

## Project layout
```
Demo2Video-Installer/
├─ install.bat            # installs deps, runs setup
├─ run.bat                # resolves Node/Python and launches everything
├─ bootstrap.ps1          # one-liner entry point (downloads + runs install)
└─ cs-demo-processor/
   ├─ main.py             # processor + web server
   ├─ setup.py            # interactive config
   ├─ setup_youtube_auth.py
   └─ csdm-fork/          # forked CSDM CLI + dev server
      ├─ scripts/develop-cli.mjs
      └─ (optional) .nvmrc  -> 20.19.1
```
