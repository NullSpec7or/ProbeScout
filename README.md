# Probe Scout 

**Probe Scout** is a lightweight Bash tool for probing Spring Boot Actuator endpoints.
It automates the discovery of exposed actuator routes, collects JSON responses (and heapdumps), and organizes results into a structured directory for offline analysis.

---

## ✨ Features

* Probes common Actuator endpoints under `/actuator` and `/api/actuator`
* Automatically parses *mappings* to discover additional Actuator paths
* Saves reachable endpoints’ JSON responses and heapdumps into a filesystem layout derived from the target base URL
* Skips `4xx` responses and follows redirects for body retrieval
* Minimal dependencies (just Bash + standard GNU tools)

---

## ⚙️ Requirements

* **Bash** (`#!/usr/bin/env bash`) — *not* `/bin/sh`
* **curl**
* GNU **coreutils**: `grep`, `sed`, `sort`, `mktemp`
* *(Optional)* `dos2unix` — useful if script or files have Windows line endings

> ✅ Tested on Linux with Bash 4+.

---

## 📦 Installation

1. Save the script (e.g., `probescout.sh`).
2. Make it executable:

   ```bash
   chmod +x full_test.sh
   ```
3. If copied from Windows, fix line endings:

   ```bash
   dos2unix full_test.sh
   ```

---

## 🚀 Usage

Basic usage:

```bash
./full_test.sh BASE_URL
```

Example:

```bash
./full_test.sh https://domain.org
```

### Notes

* Always run with **bash**:
  If you encounter `Syntax error: '(' unexpected`, explicitly run:

  ```bash
  bash ./full_test.sh BASE_URL
  ```
* Output includes:

  * Reachable actuator URLs (printed to `stdout` and saved in `Exposed-Actuators.txt`)
  * JSON/heapdump files organized in subdirectories based on target host

Example layout:

```
example.com_actuator/index                    # /actuator JSON
example.com_api_actuator/health/index          # /api/actuator/health JSON
example.com/actuator/heapdump/heapdump         # binary heapdump
example.com/Exposed-Actuators.txt              # list of reachable endpoints
```

Each saved JSON file also has a sibling `.content-type` file with the original response header.

---

## 🔍 How It Works

1. Probes a built-in list of Actuator endpoints under `/actuator` and `/api/actuator`.
2. Requests Actuator *mappings* to discover additional paths.
3. Records only non-`4xx` responses and saves JSON/heapdump bodies into structured directories.

---

## 🛠 Troubleshooting

* **Error:** `Syntax error: '(' unexpected`

  * **Cause:** Script executed with `sh` or `dash`.
  * **Fix:** Run explicitly with bash:

    ```bash
    bash ./full_test.sh BASE_URL
    ```
  * Also check for Windows line endings:

    ```bash
    file full_test.sh
    dos2unix full_test.sh
    ```

* **Permission denied**

  * Run `chmod +x full_test.sh` or execute with bash.

* **Curl timeouts**

  * Default: 10s for quick checks, 120s for full fetches.
  * Adjust timeout values directly in the script if needed.

---

## ⚖️ Security & Ethics

Probe Scout is a penetration testing and research tool.
**Only run it against systems you own or are explicitly authorized to test.**
Unauthorized scanning of remote services may be illegal.

---

## 📜 License & Attribution

* **Author:** Rupesh Kumar (NullSpec7or)
* You may reuse, adapt, or redistribute this script.
* Please credit the original author if sharing derivatives.

