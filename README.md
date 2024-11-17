# **Computercraft ThexOS**

**ThexOS** is a ComputerCraft operating system add-in with opinionated features and automatic updates from a GitHub repository.

---

## **Table of Contents**

- [Features](#features)
- [Installation](#installation)
- [Github Actions RCON Integration](#github-actions-rcon-integration)
- [Directory Structure](#directory-structure)
- [License](#license)

---

## **Features**
- **Easy Installation**: Bootstrap from a single command (bootstrap.lua)
- **Automated Updates**: Automatically checks for updates and downloads the latest scripts from the GitHub repository (computer/thexos/update.lua)
- **Startup Script**: Deploys an isolated startup script (computer/thexos/startup.lua) and injects to the system (computer/startup.lua)

---

## **Installation**
- On your ComputerCraft computer, enter the following command:

  ```
  wget run https://raw.githubusercontent.com/liquidthex/computercraft-thexos/main/bootstrap.lua
  ```

- This command downloads and runs the `bootstrap.lua` script, which handles the initial setup.
- After the computer reboots, ThexOS will be up and running.
- The system will automatically check for updates on startup.

---

## **Directory Structure**

- **computer/ Directory**
  This directory is deployed by update.lua to the ComputerCraft computer in the **root directory of the computer** and contains the following files:
  - `startup.lua`: Minimal script that runs `thexos/boot.lua`.
  - `.thexos_commit_hash` (on computer only): Stores the commit hash of the last repo update.
  - `update.lua` (on computer only): Temporarily stored during updates, deleted after use.

- **`computer/thexos/` Directory**
  Contains all ThexOS scripts and files.
  - `boot.lua`: Main boot script (launched by startup.lua)
  - `motd.txt`: Text file displayed after startup.

  - Other scripts and modules as needed.

- **Root of Repository**
  - `update.lua`: Script for downloading and running updates on computer startup.
  - `bootstrap.lua`: Script for deploying the initial system, basically downloads and runs update.lua.

---

## **License**

This project is licensed under the [MIT License](LICENSE). You are free to use, modify, and distribute ThexOS in accordance with the license terms.

---

**Thank you for using ThexOS! Happy automating!**