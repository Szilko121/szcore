# 📦 szcore

[![SzCore Resource](https://img.shields.io/badge/SzCore-FiveM%20Resource-00f0ff?style=for-the-badge&logo=fivem&logoColor=white)](https://github.com/Szilko121/SzCore-Framework)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

> Az SzCore szíve - Játékos állapotkezelés, központi exportok, szerver callbackek és eseménykezelő.  
> *The heartbeat of SzCore - Player state management, core exports, server callbacks, and event pipeline.*

---

## ✨ Főbb Jellemzők (Features)
- 🚀 **Alacsony erőforráshasználat (0.00ms idle)**
- 🔒 **Szerveroldali hitelesítés és biztonsági ellenőrzések**
- 🌐 **Többnyelvűség (i18n): Magyar (HU) & Angol (EN)**
- 🧩 **Szerves integráció az SzCore ökoszisztémával**
- 🔄 **Nyílt exportok és események (Events & Callbacks)**

---

## 📋 Követelmények (Requirements)
- FiveM Server Artifacts (minimum `v5848` vagy frissebb)
- [`szcore`](https://github.com/Szilko121/szcore)
- `oxmysql`
- `ox_lib` (ajánlott)

---

## 📥 Telepítés (Installation)

1. Töltsd le vagy klónozd a repository-t a szervered `resources` mappájába:
   ```bash
   git clone https://github.com/Szilko121/szcore.git
   ```
2. Add hozzá a `server.cfg` konfigurációs fájlodhoz:
   ```cfg
   ensure szcore
   ```
3. Szükség esetén szabd testre a `config.lua` fájlban található beállításokat.

---

## 💻 Exportok & Használat (Exports)

```lua
-- Kliensoldali lekérdezés példa:
local isReady = exports['szcore']:isReady()

-- Szerveroldali esemény példa:
TriggerEvent('szcore:server:notify', source, 'Sikeres művelet!')
```

---

## 📜 Licenc
Kiadva a **MIT** licenc alatt. Részletekért lásd a `LICENSE` fájlt.
