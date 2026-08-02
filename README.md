# Syswatch Student PC App

## Overview

The **Syswatch Student PC App** is the workstation-side application installed on every laboratory computer.

It has been converted from Firebase into an **intranet-only application** that uses:

- Flutter for Windows
- PHP local API
- MariaDB central database
- SQLite local database
- Laboratory LAN or private network

Public internet is not required.

---

## Main Purpose

The Student PC App:

- Requires student authentication before normal PC use
- Monitors the workstation and connected peripherals
- Records the current and last known student
- Stores records locally when the server is unavailable
- Synchronizes pending records automatically
- Continues monitoring while hidden or running in the system tray

---

## Added and Updated Features

### 1. Intranet student authentication

Students now log in through the local PHP/MariaDB server.

When the server is reachable:

1. The student enters a Student ID and password.
2. The app sends the credentials to the local PHP API.
3. MariaDB verifies the account.
4. The account is cached in SQLite for offline use.
5. The login is recorded.

The app no longer uses Firebase Authentication.

### 2. SQLite offline login

When the local server cannot be reached:

1. The app checks the SQLite database.
2. A previously downloaded or authenticated student can still log in.
3. New records remain pending locally.
4. Synchronization resumes when the server returns.

A new student account must connect to the server at least once before offline login can work on that PC.

### 3. Automatic pending-record synchronization

The app keeps unsent records in SQLite, including:

- Login logs
- Logout logs
- Student reports
- Fault reports
- Peripheral reports
- PC health reports
- Session records
- Workstation status

When the server becomes available again:

1. The app detects the server.
2. Pending records are uploaded automatically.
3. MariaDB saves the records.
4. SQLite marks each successful record as synchronized.

Students do not need to press a manual Sync button.

### 4. Configurable server address

The local server address can be changed through the protected PC configuration screen.

Use this when XAMPP is on the same computer:

```text
http://127.0.0.1/syswatch_api
```

Use the server PC's LAN address from another computer:

```text
http://192.168.1.10/syswatch_api
```

For the VirtualBox host-only test used during development:

```text
http://192.168.56.1/syswatch_api
```

### 5. Workstation identity and token

Each Student PC has:

- Permanent workstation ID
- Permanent workstation token
- Room assignment
- PC ID
- Configured server address

Example:

```text
Room: 706
PC ID: PC-01
Workstation ID: WS-XXXXXXXX
```

The workstation token verifies that requests came from the registered PC.

### 6. Duplicate PC assignment prevention

Two computers cannot use the same room and PC ID.

Example:

```text
VM 1: 706 / PC-01
VM 2: 706 / PC-01
```

The second registration is rejected.

VM 2 must use another PC ID:

```text
706 / PC-02
```

### 7. Local QR authentication sessions

QR sessions were converted from Firestore to the local PHP API.

The Student PC App can:

- Create a local QR session
- Display a QR code
- Check the local server for approval
- Handle expiration
- Handle cancellation

The phone authentication app must also use the same PHP API for complete intranet QR authentication.

### 8. Continuous monitoring

The app continues monitoring:

- Keyboard
- Mouse
- Monitor
- Ethernet or LAN
- CPU
- RAM
- Disk
- Storage health

Monitoring can continue:

- Before student login
- During the student session
- While hidden
- While running in the system tray

### 9. Severity behavior

#### Minor problems

Examples:

- Keyboard disconnected
- Mouse disconnected
- Monitor issue

Behavior:

- Yellow warning
- Student remains logged in
- Monitoring continues
- The app checks again automatically

#### High-severity problem

Example:

- Ethernet or LAN disconnected

Behavior:

- Red warning or `PC BROKEN` screen
- High-severity report is recorded
- The app checks again after reconnection

#### Critical problems

Examples:

- CPU problem
- RAM problem
- Disk problem
- Storage-health problem

Behavior:

- Red `PC BROKEN` warning
- Critical report is recorded
- The Admin App can review the issue

### 10. Automatic recovery

When a peripheral or connection is restored:

1. Syswatch checks the device again.
2. The warning is cleared.
3. The session continues.
4. The updated status is recorded.

The student does not need to log in again for a recoverable minor issue.

### 11. Startup and tray operation

The Student PC App preserves:

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

### 12. Student reporting

Students can:

- Confirm keyboard status
- Confirm mouse status
- Confirm monitor status
- Confirm Ethernet status
- Report visible physical damage
- Report software issues
- Add comments about workstation problems

Students cannot:

- Create accounts
- Manage rooms
- View all reports
- Manage repairs
- Change workstation settings without Admin authentication

---

## How the Student App Works Now

### First-time workstation setup

1. Install the Student PC App.
2. Start the application.
3. Press `Ctrl + Shift + A`.
4. Log in using an Admin account.
5. Enter the server address.
6. Enter the room.
7. Enter the PC ID.
8. Test the local server.
9. Select **Save and Register Workstation**.
10. The app stores the workstation ID and token locally.

### Normal student login

1. The student enters a Student ID and password.
2. The app checks whether the local server is available.
3. If available, it authenticates through PHP/MariaDB.
4. If unavailable, it checks SQLite.
5. The app records the login.
6. Monitoring continues.
7. The student completes any required peripheral confirmation.
8. The active session begins.

### During the session

The app:

- Monitors hardware and peripherals
- Sends heartbeat information
- Records faults
- Keeps the student associated with the workstation
- Stores records locally if the server is unavailable
- Synchronizes records after reconnection

### Logout

When the student logs out:

1. The logout is recorded.
2. The last-known-user record is updated.
3. The app returns to the login screen.
4. Monitoring continues.
5. The next student must log in.

---

## Windows Installer

The Student installer:

- Packages the complete Flutter Windows release folder
- Installs Syswatch under Program Files
- Creates shortcuts
- Includes the Microsoft Visual C++ x64 runtime
- Prevents missing `MSVCP140.dll` and `VCRUNTIME140_1.dll` errors
- Launches Syswatch after installation

Expected installer name:

```text
Syswatch_Student_Setup_v2.3.3.exe
```

---

## Testing Completed

- API opened successfully from a VirtualBox VM
- MariaDB health returned `database: online`
- Host-only networking worked through `192.168.56.1`
- Student installer compiled successfully
- Student app installed and opened in the VM
- Workstation configuration detected the server as online
- Workstation ID and token were generated

---

## Remaining Tests

- Online student login
- Download student accounts to SQLite
- Offline login
- Pending-record synchronization
- Duplicate workstation registration
- Multiple Student PCs
- Full QR approval using the phone app
- Real keyboard disconnection
- Real mouse disconnection
- Real monitor and Ethernet testing
- Real startup and tray testing

---

## Important Notes

- Firebase data is not transferred automatically.
- Existing Firebase accounts and reports require separate migration.
- Do not delete the old Firebase project until MariaDB has been verified.
- Physical computers are still required for final hardware tests.
