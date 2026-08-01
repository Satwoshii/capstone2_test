# Syswatch Student PC App

## Overview

The **Syswatch Student PC App** is the workstation-side application installed on every laboratory computer.

Its purpose is to:

- Require student authentication before PC use.
- Monitor hardware and peripherals.
- Report workstation problems.
- Record the last known student.
- Continue operating when the local server is temporarily unavailable.
- Synchronize pending records automatically when the intranet server returns.

The app uses:

- Flutter for Windows
- SQLite for local offline data
- PHP API for intranet communication
- MariaDB for centralized records

Firebase and public-internet services are not required.

---

## Main Features

### Student authentication

- Student ID and password login.
- Online authentication through the local PHP/MariaDB server.
- Cached SQLite authentication when the server is unavailable.
- Active-account checking.
- Local session handling.
- Login and logout records.

### Workstation identity

- Configurable server address.
- Configurable room.
- Configurable PC ID.
- Permanent workstation token.
- Duplicate room/PC assignment prevention.
- Server-side workstation validation.

### Hardware and peripheral monitoring

- Keyboard status.
- Mouse status.
- Monitor status or student confirmation.
- Ethernet/LAN status.
- CPU health.
- RAM health.
- Disk and storage health.
- Visible and software issue reporting.

### Warning behavior

- Yellow warning for minor peripheral problems.
- Red `PC BROKEN` warning for high or critical problems.
- Automatic rechecking.
- Automatic recovery after a device is fixed.
- Student session remains active for minor peripheral problems.

### Offline-first operation

- Cached student accounts in SQLite.
- Pending login logs and reports.
- Pending health records.
- Automatic synchronization after the server returns.
- Records remain pending until the server confirms success.

### Desktop behavior

- Windows startup support.
- Kiosk or blocking login flow.
- Tray/background operation.
- Monitoring continues while hidden.
- `Ctrl + Shift + A` opens protected Admin configuration.

### QR sessions

- Creates a QR login session through the local API.
- Displays a QR code.
- Polls the local server for approval.
- Supports session expiration and cancellation.

A compatible phone client must approve the QR session through the same local API.

---

## Student Permissions

Students can:

- Log in before using the PC.
- Confirm keyboard, mouse, monitor, and Ethernet status.
- Report visible hardware damage.
- Report software issues.
- Continue after minor peripheral warnings.
- Use an offline cached account.

Students cannot:

- Create accounts.
- Manage rooms.
- Register another PC.
- View all reports.
- Access repair management.
- Change the server address without Admin authentication.

---

## Requirements

### Development

- Flutter SDK
- Windows desktop support
- Visual Studio with Desktop development with C++
- Working PHP/MariaDB Syswatch server

### Runtime

- Windows 10 or Windows 11
- Access to the laboratory LAN
- Configured Syswatch server address
- Registered workstation identity

---

## Installation

### 1. Install dependencies

From the Flutter project folder:

```powershell
flutter clean
flutter pub get
flutter analyze
```

### 2. Build the Windows app

```powershell
flutter build windows --release
```

The release files are normally located in:

```text
build\windows\x64\runner\Release
```

Copy the entire Release folder. Do not copy only the `.exe`.

### 3. Run the app

Launch the Syswatch executable.

For final deployment, create a Windows installer or configure Windows startup using the included startup service.

---

## First-Time Configuration

### Same computer as XAMPP

Use:

```text
http://127.0.0.1/syswatch_api
```

### Different laboratory computer

Use the server PC's LAN address:

```text
http://192.168.1.10/syswatch_api
```

### Configure the workstation

1. Start Syswatch.
2. Press `Ctrl + Shift + A`.
3. Log in using an Admin account.
4. Enter the server address.
5. Enter the room, for example `706`.
6. Enter the PC ID, for example `PC-01`.
7. Save and register the workstation.

Each PC must use a unique room/PC combination.

---

## Student Login Tutorial

### Online login

1. Ensure the Student PC is connected to the laboratory LAN.
2. Ensure Apache and MariaDB are running on the server.
3. Open Syswatch.
4. Enter the Student ID.
5. Enter the password.
6. Select **Login**.
7. Complete any required peripheral confirmation.
8. Continue to the student session.

After a successful online login, the student account is cached locally for offline use.

### Offline login

Offline login works only for accounts already cached on that PC.

1. Open Syswatch while the server is unavailable.
2. Enter the same Student ID and password.
3. Syswatch checks the SQLite account.
4. If the account is valid and active in the local cache, login continues.
5. New records are kept as pending.
6. When the server returns, synchronization starts automatically.

---

## Peripheral Confirmation Tutorial

The student may be asked to confirm:

- Keyboard
- Mouse
- Monitor
- Ethernet/LAN

For each item:

1. Check that the device is present and working.
2. Mark it as working or report the problem.
3. Add a comment when necessary.
4. Submit the form.

### Minor issue

Keyboard, mouse, and monitor problems normally show a yellow warning. The student remains logged in, and Syswatch continues checking in the background.

### High issue

Ethernet/LAN disconnection shows a red warning because the PC cannot communicate with the local server.

### Critical issue

CPU, RAM, disk, or storage health problems show a red `PC BROKEN` warning and must be reviewed by the Admin.

---

## Automatic Recovery

When a disconnected peripheral is reconnected:

1. Syswatch checks the device again.
2. The warning is cleared when the device is detected.
3. The active session continues.
4. The recovery is recorded.

---

## Tray and Background Operation

Syswatch may hide into the Windows system tray after login.

While hidden:

- Hardware monitoring continues.
- Peripheral checks continue.
- Pending synchronization continues.
- The workstation heartbeat continues.
- Warning screens can still appear.

Use the tray icon or protected shortcut to reopen the app.

---

## Server Health Test

On the Student PC, open a browser and visit:

```text
http://SERVER_IP/syswatch_api/health.php
```

Example:

```text
http://192.168.1.10/syswatch_api/health.php
```

Expected response:

```json
{
  "success": true,
  "status": "online",
  "database": "online"
}
```

---

## Troubleshooting

### The app cannot reach the server

Check:

- Apache is running.
- MariaDB is running.
- The server IP is correct.
- The PC is on the same LAN.
- Windows Firewall allows Apache on private networks.
- `health.php` opens from the Student PC browser.

### Do not use `localhost` on another PC

This is wrong on a different Student PC:

```text
http://127.0.0.1/syswatch_api
```

Use the server's LAN IP instead:

```text
http://192.168.1.10/syswatch_api
```

### Offline login fails

Possible causes:

- The account was never cached on this PC.
- The password changed after the last download.
- The account is disabled.
- The SQLite database was deleted or moved.

Connect to the server and log in once to refresh the local account.

### Duplicate workstation error

Another computer already owns the same room/PC assignment.

Use a unique value such as:

```text
706 / PC-02
```

or release/reassign the existing workstation through the Admin App.

### Build errors after removing Firebase

Run:

```powershell
flutter clean
Remove-Item -Recurse -Force .dart_tool -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force windows\flutter\ephemeral -ErrorAction SilentlyContinue
Remove-Item -Force pubspec.lock -ErrorAction SilentlyContinue
flutter pub get
flutter analyze
```

---

## Important Notes

- Student accounts are created through the Admin App.
- The Student PC app does not support self-registration.
- Firebase data is not migrated automatically.
- Pending SQLite records must not be deleted before synchronization.
- The app should be tested on real laboratory computers before final deployment.
