# Limbus Company Cache Relocation (Windows)

Move **Limbus Company**'s Unity cache off your `C:` drive, and keep it moved.

The game writes its cache to `%LOCALAPPDATA%Low\Unity\ProjectMoon_LimbusCompany` — it grows to
10 GB+ over time and easily fills a small system drive. This tool points that path at another
drive using a **junction** (a directory symlink), so the game keeps reading and writing exactly
where it expects, while the data actually lives elsewhere.

The interesting part is not creating the link — it's **keeping it alive**. Game reinstalls and
"repair installation" steps happily replace the link with a real folder on `C:`, and you're back
to square one. This script detects that, moves the contents back to the target drive, verifies the
source is empty, and rebuilds the link. If anything fails, it stops and leaves your files alone.

---

## What it touches

| Path | Role |
|---|---|
| `%LOCALAPPDATA%Low\Unity\ProjectMoon_LimbusCompany` | The **link** (junction) |
| `D:\LimbusCache` (configurable) | The **real** cache directory |

Save data lives in a different folder (`%LOCALAPPDATA%Low\ProjectMoon\LimbusCompany`) and is **not
touched**.

---

## Usage

### 1. Configure (optional)

Copy `config.example.json` to `config.json` and edit:

```json
{
  "Link": "C:\\Users\\<you>\\AppData\\LocalLow\\Unity\\ProjectMoon_LimbusCompany",
  "Target": "D:\\LimbusCache",
  "GameProcess": "LimbusCompany"
}
```

- `Link` — where the game expects its cache
- `Target` — where you want the cache to live
- `GameProcess` — used to skip work while the game is running

### 2. Run

Double-click `一键修复.cmd`, or:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Fix-LimbusCacheLink.ps1
```

Steps:

1. Game running → do nothing, exit (avoids fighting over files)
2. Target missing → create it
3. Link correct → report and exit
4. Link pointing elsewhere → remove and recreate
5. **Link replaced by a real directory** (typical after a reinstall) → `robocopy /MOVE` the contents
   back to the target, verify the source is empty, then recreate the link
6. Any failure → stop, change nothing, log the reason

### 3. Run at logon (optional)

Task Scheduler → Create Task → trigger "At log on" → action:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\path\to\Fix-LimbusCacheLink.ps1" -Quiet
```

`-Quiet` writes to the log only, no console output.

---

## Log

`%LOCALAPPDATA%\LimbusCacheLink\fix-link.log` — one line per run.

---

## FAQ

**The cache went back to `C:` after an update / reinstall — now what?**
Run the script again. It detects the real folder, moves it back, and rebuilds the link. Adding it to
Task Scheduler at logon saves you the trouble.

**Can it lose data?**
The source directory is only removed after a successful move and an emptiness check.
Every failure path stops before modifying anything. `robocopy /MOVE` copies first, then deletes.

**Does it work for other Unity games?**
Yes. Point `Link` at that game's folder under `LocalLow\Unity` and set `GameProcess` accordingly.

**Does deleting the junction delete the cache?**
No — a junction is just a signpost. The script removes it with `rmdir`, which only removes the link.
Deleting the *target* directory, of course, deletes the files.

---

## License

MIT.
