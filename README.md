# RHTLC Setup Script (Windows)

Automates the Red Hat Training Lab Companion (RHTLC) setup on Windows — installs RHTLC, checks for Ncat, connects to your classroom lab, opens the OpenShift console in a proxied Chrome, and SSHes into the workstation.

Official RHTLC docs: https://redhattraining.github.io/RHTLC_Docs/

## Prerequisites

- [Nmap](https://nmap.org/download.html) installed (provides Ncat, required by RHTLC)
- Google Chrome installed

## First-Time Setup

1. Open **PowerShell** and download the script:
   ```powershell
   Invoke-WebRequest -Uri "https://raw.githubusercontent.com/rh-ee-ggaurav/rhtlc-windows/main/rhtlc-setup.ps1" -OutFile "rhtlc-setup.ps1"
   ```

2. Run the setup:
   ```powershell
   .\rhtlc-setup.ps1
   ```
   > If you get an execution policy error, run this first:
   > ```powershell
   > Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   > ```

3. When prompted, go to the [Red Hat Online Learning Portal](https://rol.redhat.com), open the **Labs** tab, click **Create Lab**, then **COPY RHTLC URL** and paste it into the terminal.

4. A Chrome window will open with proxy configured. Navigate to the URL from `oc whoami --show-console` (run inside the workstation).
   - If you see a security warning, click **Advanced** then **Proceed**

5. The script will SSH you into the workstation. Once inside, run:
   ```bash
   oc login -u admin -p redhatocp https://api.lab.example.com:6443
   oc whoami --show-console
   ```
   - SSH Password: `student`

## Daily Use

```powershell
.\rhtlc-setup.ps1 daily
```

## Three Important Rules

1. Run `rhtlc connect` only **ONCE** per lab session
2. RHTLC runs on Windows; `oc` runs inside the workstation
3. Chrome uses the SOCKS5 proxy `127.0.0.1:1080`

## All Commands

| Command | What it does |
|---------|-------------|
| `.\rhtlc-setup.ps1 full` | Full first-time setup (default) |
| `.\rhtlc-setup.ps1 daily` | Daily reconnect |
| `.\rhtlc-setup.ps1 install` | Install RHTLC + Ncat check + self-check |
| `.\rhtlc-setup.ps1 connect` | Connect to classroom |
| `.\rhtlc-setup.ps1 cleanup` | Manage existing connections |
| `.\rhtlc-setup.ps1 browser` | Launch proxied Chrome |
| `.\rhtlc-setup.ps1 ssh` | SSH into workstation |
| `.\rhtlc-setup.ps1 troubleshoot` | Test proxy connectivity |
| `.\rhtlc-setup.ps1 disconnect` | Disconnect all connections |
