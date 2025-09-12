import os
import configparser
import json
from getpass import getpass

def clear_screen():
    """Clears the terminal screen."""
    os.system('cls' if os.name == 'nt' else 'clear')

def get_valid_path(prompt, must_exist=True):
    """Prompts the user for a path and validates it."""
    while True:
        path = input(prompt).strip()
        if must_exist and not os.path.exists(path):
            print("\nERROR: The path you entered does not exist. Please try again.\n")
            continue
        if not must_exist:
            parent_dir = os.path.dirname(path)
            if parent_dir and not os.path.exists(parent_dir):
                os.makedirs(parent_dir, exist_ok=True)
        return path

def main():
    """Runs the interactive setup process for both applications."""
    clear_screen()
    print("=================================================================")
    print("== Welcome to the CS Demo Processor Interactive Setup          ==")
    print("=================================================================")
    print("\nThis script will help you create the configuration files for both the")
    print("main application and the CS Demo Manager fork.")
    print("\nPlease have the following information ready:")
    print("  - The password for the PostgreSQL database user.")
    print("  - The full path to the folder where OBS saves its recordings.")
    print("\nPress Enter to begin...")
    input()
    clear_screen()

    # --- Get CSDM Database Settings ---
    print("--- Step 1: CS Demo Manager Database Configuration ---\n")
    print("The CSDM fork needs to connect to your PostgreSQL database.")
    print("The default user is 'csdm' and the database is 'csdm'.")
    db_password = getpass("Enter the PostgreSQL password for the 'csdm' user in the public csdm instance(look in discord): ")

    # --- Create CSDM configurations in all required locations ---
    
    # Location 1: .csdm-dev/settings.json (for developer mode)
    csdm_settings_dir_dev = os.path.expanduser("~/.csdm-dev")
    os.makedirs(csdm_settings_dir_dev, exist_ok=True)
    settings_json_path_dev = os.path.join(csdm_settings_dir_dev, 'settings.json')
    
    csdm_config_json = {
      "database": {
        "host": "csdm.xify.pro",
        "port": 8432,
        "user": "csdm",
        "password": db_password,
        "database": "csdm"
      },
      "playback": {
        "width": 1280,
        "height": 720,
        "closeGameAfterHighlights": True
      }
    }
    
    try:
        with open(settings_json_path_dev, 'w') as f:
            json.dump(csdm_config_json, f, indent=4)
        print(f"\n[SUCCESS] Created dev settings file at: {settings_json_path_dev}")
    except Exception as e:
        print(f"\n[ERROR] Could not create dev settings file. {e}")

    # Location 2: .csdm/settings.json (for production/installed mode)
    csdm_settings_dir_prod = os.path.expanduser("~/.csdm")
    os.makedirs(csdm_settings_dir_prod, exist_ok=True)
    settings_json_path_prod = os.path.join(csdm_settings_dir_prod, 'settings.json')
    try:
        with open(settings_json_path_prod, 'w') as f:
            json.dump(csdm_config_json, f, indent=4)
        print(f"[SUCCESS] Created prod settings file at: {settings_json_path_prod}")
    except Exception as e:
        print(f"\n[ERROR] Could not create prod settings file. {e}")

    # Location 3: csdm-fork/.env file
    env_file_path = os.path.join(os.getcwd(), 'csdm-fork', '.env')
    env_content = f"VITE_DATABASE_URL=postgresql://csdm:{db_password}@csdm.xify.pro:8432/csdm"
    try:
        with open(env_file_path, 'w') as f:
            f.write(env_content)
        print(f"[SUCCESS] Created .env file at: {env_file_path}")
    except Exception as e:
        print(f"\n[ERROR] Could not create .env file. {e}")
        
    clear_screen()

    # --- Get Main App Settings ---
    print("--- Step 2: Main Application Configuration ---\n")
    output_folder = get_valid_path("Enter the full path to your OBS output folder (e.g., Z:\\Videos\\OBS):\n> ")
    obs_host = input("Enter the OBS WebSocket host (usually 'localhost'):\n> ") or 'localhost'
    obs_port = input("Enter the OBS WebSocket port (usually '4455'):\n> ") or '4455'

    # --- Create Main App config.ini ---
    main_app_config = configparser.ConfigParser()
    main_app_config['Paths'] = {
        'output_folder': output_folder
    }
    main_app_config['OBS'] = {
        'host': obs_host,
        'port': obs_port
    }

    try:
        with open('config.ini', 'w') as configfile:
            main_app_config.write(configfile)
        print("\n--- Success! ---\n")
        print("'config.ini' has been created successfully.")
    except Exception as e:
        print(f"\nERROR: An error occurred while writing the config file: {e}")
        input("\nPress Enter to exit.")
        return

    print("\n=================================================================")
    print("== Configuration complete. What's next?                      ==")
    print("=================================================================")
    print("\n1. YouTube Setup: Run 'python setup_youtube_auth.py' to authorize the app.")
    print("\n2. Start Servers: Follow the 'How to Run' steps in the README file.")
    print("\n3. If you want to connect to your own postgresql database, you can edit the settings.json file")
    
    input("\nPress Enter to exit the setup.")

if __name__ == "__main__":
    main()
