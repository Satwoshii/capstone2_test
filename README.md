# Syswatch Student PC App

## Version

```text
v2.4.1
```

## Overview

The **Syswatch Student PC App** is the workstation-side application installed on every laboratory computer.

Syswatch has been converted into an **intranet-only computer laboratory authentication, hardware monitoring, reporting, and support system** using:

- Flutter Windows
- PHP local API
- MariaDB central database
- SQLite local database
- Apache/XAMPP
- Laboratory LAN or private network

Firebase and Firestore are no longer used by the active Student PC App.

Public internet is not required.

---

## Main Purpose

The Student PC App:

- Requires student authentication before normal PC use
- Supports online login through PHP and MariaDB
- Supports SQLite offline login
- Monitors hardware and peripherals
- Records the current and last known student
- Stores pending records locally
- Synchronizes records automatically
- Displays severity-based warning screens
- Opens ITSO Support Chat only when the PC has an active issue
- Continues running through Windows startup and the system tray

---

## Student Authentication

### Online login

When the intranet server is reachable:

1. The student enters a Student ID and password.
2. The app sends the credentials to the PHP API.
3. MariaDB verifies the account.
4. The account is cached in SQLite.
5. The student session begins.
6. Login information is recorded.

### Offline login

When the local server is unavailable:

1. The app checks SQLite.
2. A previously cached student account can still log in.
3. New records are saved locally as pending.
4. The records synchronize when the server becomes available again.

A student account must first be downloaded or authenticated while the server is online before offline login can work on that PC.

---

## Automatic Synchronization

The Student App stores unsent records in SQLite when the server is unavailable.

Examples include:

- Login records
- Logout records
- Student issue reports
- PC health reports
- Peripheral reports
- Hardware fault reports
- Session records
- Workstation status
- Pending chat messages

When the server reconnects:

1. The app detects the intranet server.
2. Pending records are uploaded through the PHP API.
3. MariaDB stores the records.
4. SQLite marks successful records as synchronized.

Students do not need to press a manual Sync button.

---

## Workstation Identity

Each Student PC has:

- Configurable server URL
- Room assignment
- PC ID
- Permanent workstation ID
- Permanent workstation token

Example:

```text
Server: http://192.168.1.10/syswatch_api
Room: 706
PC ID: PC-03
Workstation ID: WS-XXXXXXXX
```

The workstation token verifies requests from the registered PC.

---

## Duplicate PC Assignment Prevention

Syswatch prevents two computers from registering the same room and PC ID.

Example:

```text
PC 1: 706 / PC-03
PC 2: 706 / PC-03
```

The second registration is rejected.

The second computer must use another PC ID, such as:

```text
706 / PC-04
```

---

## Hardware and Peripheral Monitoring

The Student App monitors:

- Keyboard
- Mouse
- Monitor
- Ethernet or LAN connection
- CPU
- RAM
- Disk
- Storage health

Students can also report issues that may not be detected automatically:

- Dead pixels
- Flickering monitor
- Damaged keyboard keys
- Mouse button problems
- Loose or damaged cables
- Visible physical damage
- Applications that do not open
- Other software problems

Monitoring can continue:

- Before login
- During an active session
- While the app is hidden
- While the app is running in the system tray

---

## Warning Severity

### Minor problems

Examples:

- Keyboard disconnected
- Mouse disconnected
- Monitor issue

Behavior:

- Yellow warning
- Student remains logged in
- Monitoring continues
- Syswatch automatically checks again

### High-severity problems

Example:

- Ethernet or LAN disconnected

Behavior:

- Red warning or `PC BROKEN` screen
- High-severity report is recorded
- Syswatch checks again after reconnection

### Critical problems

Examples:

- CPU issue
- RAM issue
- Disk issue
- Storage-health issue

Behavior:

- Red `PC BROKEN` warning
- Critical report is recorded
- The Admin App can review the issue
- ITSO Support Chat becomes available after the issue is synchronized

---

## Automatic Recovery

When a disconnected device or connection is restored:

1. Syswatch checks the device again.
2. The warning is cleared when recovery is confirmed.
3. The student session continues.
4. The updated status is recorded.

The student does not need to log in again for a recoverable issue.

---

## Issue-Gated ITSO Support Chat

The ITSO Support Chat is **not always available**.

The chat is enabled only after Syswatch has created an active unresolved issue for the current workstation.

```text
No active issue
→ Chat disabled

Issue detected or reported
→ Fault report created
→ Chat enabled

Issue resolved or closed
→ Chat becomes read-only
```

### Chat can open after

- Automatically detected hardware or peripheral issue
- Student-submitted hardware issue
- Student-submitted peripheral issue
- Student-submitted network issue
- Student-submitted software issue
- Student-submitted visible-damage report

### Student chat features

The student can:

- Open a conversation linked to the active issue
- Send text messages to ITSO Support
- View Admin replies
- View message timestamps
- View unread-message status
- See the room, PC, issue type, and severity
- Continue the conversation while the issue remains active

The student cannot:

- Start a chat without an active issue
- View another student's chat
- Change issue severity
- Mark the issue as repaired
- Delete Admin replies

### Chat states

```text
ITSO Support unavailable
```

The issue has not reached the server yet, no active issue exists, or the server is unavailable.

```text
Chat with ITSO Support
```

The issue exists in MariaDB and is active.

```text
Issue resolved — View conversation
```

The issue has been resolved and the chat is read-only.

### Chat record relationship

Each chat conversation is linked to:

- Fault report
- Student account
- Workstation
- Room
- PC ID
- Student session
- Assigned Admin
- Issue status

---

## Local QR Authentication Sessions

QR sessions were converted from Firestore to the local PHP API.

The Student App can:

- Create a local QR session
- Display a QR code
- Check the local server for approval
- Handle expiration
- Handle cancellation

The phone authentication app must also use the PHP API for full intranet QR authentication.

---

## Startup, Tray, and Protected Configuration

The Student App includes:

- Windows startup support
- Blocking login screen
- System tray operation
- Background monitoring
- Background synchronization
- Workstation heartbeat
- Protected Admin shortcut

The Admin shortcut is:

```text
Ctrl + Shift + A
```

This shortcut opens Admin authentication and workstation configuration.

Students cannot change the server address, room, PC ID, or workstation identity without Admin authorization.

---

## Server Address

Use this when XAMPP is running on the same computer:

```text
http://127.0.0.1/syswatch_api
```

Use the server PC's LAN address from another computer:

```text
http://192.168.1.10/syswatch_api
```

VirtualBox host-only development address:

```text
http://192.168.56.1/syswatch_api
```

Do not use `127.0.0.1` from a different PC because it refers to that PC itself.

---

## Windows Installer

The Student installer:

- Packages the complete Flutter Windows Release folder
- Includes Flutter data, plugins, and DLL files
- Includes the Microsoft Visual C++ x64 runtime
- Creates a Start Menu shortcut
- Can create a desktop shortcut
- Can create a Windows startup shortcut
- Prevents missing `MSVCP140.dll` and `VCRUNTIME140_1.dll` errors

Expected installer:

```text
Syswatch_Student_Setup_v2.4.1.exe
```

---

## Testing Completed

- Student App opens on a clean Windows VM
- PHP API is reachable from the VM
- MariaDB health returns online
- VirtualBox host-only networking works
- Workstation configuration detects the server
- Permanent workstation ID and token are generated
- Student installer includes the Visual C++ runtime
- The updated Student App displays the ITSO Support control
- The support control remains unavailable until an active issue exists on the server

---

## Remaining Tests

- Online Student login
- SQLite offline login
- Automatic pending-record synchronization
- Multiple Student PCs
- Duplicate workstation rejection
- Full student-to-Admin chat exchange
- Chat read/unread behavior
- Chat after issue resolution
- Full QR approval using the phone app
- Physical keyboard disconnection
- Physical mouse disconnection
- Physical monitor testing
- Physical Ethernet removal
- CPU, RAM, disk, and storage monitoring on real PCs
- Windows startup and tray behavior on laboratory PCs

---

## Important Notes

- Existing Firebase data is not transferred automatically.
- Historical accounts, rooms, reports, and logs require separate migration.
- The Student App installer does not install the PHP API or MariaDB schema.
- The chat PHP files and corrected chat tables must be installed separately on the server.
- Do not delete the old Firebase project until required records have been migrated.
