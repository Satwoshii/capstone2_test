# Syswatch Student PC App

This `lib` folder uses an intranet-only architecture:

- PHP/MariaDB central server over the laboratory LAN
- SQLite cached student accounts for offline login
- SQLite pending records with automatic local-server synchronization
- Workstation registration and permanent workstation tokens
- Local QR authentication sessions
- Windows hardware and peripheral monitoring
- Startup, tray operation, warnings, recovery, and Ctrl + Shift + A

The Student PC app contains only student workstation functions plus the protected
ITSO/Admin workstation-configuration login. Full management functions belong in
the separate Staff app.
