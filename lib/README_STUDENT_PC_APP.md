# Syswatch Student PC App

This `lib` folder uses an intranet-only architecture:

- PHP/MariaDB central server over the laboratory LAN
- Server-verified Student ID/password login over the laboratory LAN
- One active workstation session per student account
- 20-second session heartbeat with a 90-second crash timeout
- SQLite pending records with automatic local-server synchronization
- Workstation registration and permanent workstation tokens
- Windows hardware and peripheral monitoring
- Startup, tray operation, warnings, recovery, and Ctrl + Shift + A

The Student PC app contains only student workstation functions plus the protected
ITSO/Admin workstation-configuration login. Full management functions belong in
the separate Staff app.

Student password login requires the local Syswatch server so duplicate sessions
can be prevented. Internet access is not required.
