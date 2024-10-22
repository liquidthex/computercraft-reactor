# **Computercraft ThexOS**

Welcome to **ThexOS**, a set of ComputerCraft scripts designed to manage and automate tasks on your ComputerCraft computers in Minecraft. This guide will walk you through setting up ThexOS on your computer, explain how it works, and help you get started quickly.

---

## **Table of Contents**

- [Introduction](#introduction)
- [Features](#features)
- [Installation](#installation)
- [How It Works](#how-it-works)
  - [Bootstrapping with `bootstrap.lua`](#bootstrapping-with-bootstraplua)
  - [Updating with `update.lua`](#updating-with-updatelua)
  - [Boot Process with `boot.lua`](#boot-process-with-bootlua)
  - [Peripheral Detection and Script Execution](#peripheral-detection-and-script-execution)
  - [Running Scripts in the Background](#running-scripts-in-the-background)
- [Directory Structure](#directory-structure)
- [License](#license)
- [Contributing](#contributing)
- [Support](#support)

---

## **Introduction**

ThexOS is a modular and extensible operating system for ComputerCraft computers in Minecraft. It automates the process of updating scripts from a GitHub repository, manages peripheral detection, and runs designated programs in the background, allowing you to focus on building and automating your Minecraft world.

---

## **Features**

- **Easy Installation**: Set up ThexOS on your ComputerCraft computer with a single command.
- **Automated Updates**: Automatically checks for updates and downloads the latest scripts from the GitHub repository.
- **Peripheral Detection**: Detects connected peripherals and runs corresponding scripts.
- **Background Execution**: Runs designated scripts in the background using multishell, keeping your console free.
- **Modular Design**: Easily add or modify scripts to suit your needs.
- **Clean File System**: Keeps your root directory uncluttered by organizing scripts in a dedicated folder.

---

## **Installation**

Follow these simple steps to install ThexOS on your ComputerCraft computer:


1. **Run the Bootstrap Script**

   - On your ComputerCraft computer, enter the following command:

     ```
     wget run https://raw.githubusercontent.com/liquidthex/computercraft-thexos/main/bootstrap.lua
     ```

   - This command downloads and runs the `bootstrap.lua` script, which handles the initial setup.

2. **Wait for the Installation to Complete**

   - The bootstrap script will:

     - Download the latest `update.lua` script.
     - Run `update.lua` to download all necessary files.
     - Create a `startup.lua` script if it doesn't exist.
     - Reboot the computer to apply updates.

3. **Enjoy ThexOS**

   - After the computer reboots, ThexOS will be up and running.
   - The system will automatically check for updates on startup and run designated scripts based on connected peripherals.

---

## **How It Works**

### **Bootstrapping with `bootstrap.lua`**

The `bootstrap.lua` script is the entry point for installing ThexOS. When you run the bootstrap command, the script performs the following actions:

- **Retrieves the Latest Commit Hash**

  - Uses the GitHub API to fetch the latest commit hash from the `computercraft-thexos` repository.

- **Downloads `update.lua`**

  - Downloads the `update.lua` script from the root of the repository using the latest commit hash.

- **Runs `update.lua`**

  - Executes `update.lua` to download all necessary files and scripts.

- **Creates `startup.lua`**

  - Checks if `startup.lua` exists on the computer.
  - If not, creates a minimal `startup.lua` that runs `thexos/boot.lua` on startup.

- **Reboots the Computer**

  - Reboots the computer to apply updates and start the system.

### **Updating with `update.lua`**

The `update.lua` script is responsible for keeping ThexOS up to date:

- **Downloads Files from the Repository**

  - Recursively downloads all files from the `computer/` directory in the repository.
  - Preserves the directory structure on the computer.

- **Deletes Old Files**

  - Deletes the existing `thexos` directory before downloading new files.
  - Ensures that renamed or deleted files are handled properly.

- **Keeps the Root Directory Clean**

  - Downloads scripts and files into the appropriate directories, avoiding clutter in the root directory.

### **Boot Process with `boot.lua`**

The `boot.lua` script is the core of ThexOS, handling the boot process and updates:

- **Checks for Updates**

  - Retrieves the latest commit hash from the repository.
  - Compares it with the stored commit hash on the computer.
  - If there's a new commit, downloads and runs `update.lua`.

- **Runs Updates**

  - After running `update.lua`, saves the new commit hash.
  - Reboots the computer to apply updates.

- **Continues Boot Process**

  - If no update is needed, proceeds with the boot process.

### **Peripheral Detection and Script Execution**

`boot.lua` detects connected peripherals and runs corresponding scripts:

- **Detects Monitor and Reactor**

  - Uses `peripheral.find("monitor")` and `peripheral.find("fissionReactorLogicAdapter")` to detect peripherals.

- **Runs `reactorControl.lua`**

  - If both a monitor and reactor are detected, runs `reactorControl.lua`.
  - Launches the script in the background, allowing the console to remain free.

- **Displays Message of the Day**

  - Reads and prints the contents of `thexos/motd.txt` upon successful startup.

### **Running Scripts in the Background**

ThexOS uses the `multishell` API to run scripts in the background:

- **Uses `multishell.launch`**

  - Launches `reactorControl.lua` in a new tab using `multishell.launch({}, "thexos/reactorControl.lua")`.
  - Requires CC: Tweaked, which supports multishell functionality.

- **Keeps Console Free**

  - Running scripts in the background allows you to use the console for other tasks.

- **Fallback Option**

  - If `multishell` is not available, ThexOS runs the script in the foreground as a fallback.

---

## **Directory Structure**

ThexOS organizes files in a clean and logical structure:

- **Root Directory**

  - `startup.lua`: Minimal script that runs `thexos/boot.lua`.
  - `.thexos_commit_hash`: Stores the commit hash of the last update.
  - `update.lua`: Temporarily stored during updates, deleted after use.

- **`thexos/` Directory**

  - Contains all ThexOS scripts and files.
  - `boot.lua`: Main boot script.
  - `reactorControl.lua`: Script that manages the reactor (not detailed here).
  - `motd.txt`: Message of the day displayed on startup.
  - Other scripts and modules as needed.

---

## **License**

This project is licensed under the [MIT License](LICENSE). You are free to use, modify, and distribute ThexOS in accordance with the license terms.

---

**Thank you for using ThexOS! Happy automating!**