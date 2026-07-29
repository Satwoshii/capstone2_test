# Syswatch Student PC App

## User Tutorial and Feature Guide

Syswatch is a Windows application for computer laboratories. It requires a
student to sign in before using a laboratory PC, checks the workstation and its
peripherals, records detected or reported problems, and continues monitoring
while running in the background.

The application is offline-first. Records are saved locally in SQLite when the
internet is unavailable and are automatically synchronized to Firebase when a
connection becomes available.

---

## 1. Main Features

### Student access and authentication

- Requires student authentication before the laboratory PC can be used.
- Supports online authentication and offline login.
- Downloads authorized student accounts to the local SQLite database.
- Keeps the active student session during recoverable peripheral problems.
- Records login and logout activity.

> A new installation must connect to the internet at least once to download
> student accounts before offline login can be used.

### Offline-first operation

- Saves records locally in SQLite.
- Allows downloaded student accounts to log in without internet.
- Keeps unsynchronized records in a pending state.
- Automatically uploads pending records when internet access returns.
- Does not require students to press a manual sync button.

### Workstation monitoring

Syswatch checks the following devices and connections:

- Physical keyboard
- Mouse
- Monitor
- Ethernet/LAN connection
- CPU status
- RAM status
- Disk and storage status

Monitoring runs approximately every five seconds while the application is
visible or hidden in the background.

### Fault detection and recovery

- Shows a warning when a monitored problem is detected.
- Treats keyboard, mouse, and monitor disconnections as recoverable peripheral
  issues.
- Keeps the student logged in during a recoverable peripheral warning.
- Automatically rechecks a disconnected device.
- Removes the warning after the student reconnects or fixes the device.
- Shows a serious `PC BROKEN` warning for critical workstation problems.
- Records detected faults for later review by ITSO staff.

### Student reporting

Students can:

- Confirm or report a keyboard problem.
- Confirm or report a mouse problem.
- Confirm or report a monitor problem.
- Confirm or report an Ethernet/LAN problem.
- Report visible physical damage.
- Report software problems that automatic monitoring cannot detect.
- Add a description explaining the issue.

### Background and startup behavior

- Starts automatically with the laboratory PC when startup is enabled.
- Uses a kiosk-style screen for student access.
- Continues monitoring while hidden or running in the system tray.
- Reopens when required by the monitoring system.
- Preserves the active session while checking the workstation.

### Workstation configuration

- Assigns a permanent workstation identity.
- Stores the laboratory room and PC number.
- Records the workstation's latest status.
- Records the last known student using the PC.
- Allows an administrator to change PC configuration through a protected
  shortcut.

---

## 2. User Roles

### Student

The Student PC App only allows a student to:

1. Log in before using the PC.
2. Confirm the condition of the keyboard, mouse, monitor, and Ethernet/LAN.
3. Report visible hardware damage.
4. Report software-related problems.
5. Read and respond to workstation warnings.
6. Log out after using the computer.

Students cannot manage accounts, rooms, PC assignments, or administrative
records.

### Administrator

The administrator can use the protected shortcut to:

1. Open the administrator login.
2. Enter an authorized administrator account.
3. Configure the current laboratory room.
4. Assign the PC number.
5. Save the workstation's permanent identity.

The shortcut is:

```text
Ctrl + Shift + A
```

This shortcut is mainly for:

```text
Admin Login → Manage PC Configuration
```

### ITSO staff

ITSO staff use the separate Staff application to review synchronized
workstation information, fault reports, PC health, repair records, and last
known users. These functions are intentionally not exposed in the Student PC
App.

---

## 3. First-Time Workstation Setup

An administrator or ITSO staff member should complete these steps before
students use a newly installed workstation.

### Step 1: Install and open Syswatch

1. Run `Syswatch-Setup.exe`.
2. Approve the Windows administrator prompt.
3. Finish the installation.
4. Allow Syswatch to open after installation.

The program files are installed in the Syswatch installation folder. Local
SQLite records and workstation settings are stored separately in Windows
application data.

### Step 2: Connect to the internet

Connect the workstation to the laboratory network. The first online connection
allows Syswatch to:

- Connect to Firebase.
- Register or update the workstation.
- Download student accounts for offline login.
- Upload any pending local records.

### Step 3: Open PC Configuration

1. Press `Ctrl + Shift + A`.
2. Wait for the Administrator Login screen.
3. Enter an authorized administrator account.
4. Select or enter the laboratory room.
5. Select or enter the PC number.
6. Confirm and save the configuration.

Example:

```text
Room: 706
PC: PC-01
```

Each physical computer must have its own workstation identity. Do not assign
the same workstation identity to two different PCs.

### Step 4: Perform the initial hardware check

Keep the normal laboratory peripherals connected when Syswatch first runs:

- Keyboard
- Mouse
- Monitor
- Ethernet cable

Allow monitoring to run before testing disconnection detection. This helps the
application establish the workstation's normal physical device state.

### Step 5: Restart Windows

Restart the computer and confirm that:

1. Syswatch starts automatically.
2. The student login screen opens.
3. The workstation configuration is still saved.
4. Monitoring starts without requiring manual activation.

---

## 4. Student Tutorial

### Step 1: Start the laboratory PC

Turn on the computer. Syswatch should start automatically and display the
student access screen.

The student should not close or bypass Syswatch. The application must remain
running so it can record the session and monitor the workstation.

### Step 2: Log in

1. Enter the student ID.
2. Enter the password.
3. Select **Login**.
4. Wait for authentication and the workstation check.

When internet is available, Syswatch can use the online account and refresh the
offline account copy. When internet is unavailable, it checks the previously
downloaded account stored in SQLite.

If offline login fails:

- Check that the student ID and password are correct.
- Confirm that the account is active.
- Connect the PC to the internet so Syswatch can download the latest student
  accounts.
- Ask ITSO staff for assistance if the account has never been downloaded to
  that workstation.

### Step 3: Review the peripheral check

Syswatch checks the keyboard, mouse, monitor, and Ethernet/LAN connection.
Confirm that every required device is present and working.

If a problem is not automatically detected, use the student report form and
describe what is wrong.

Examples:

- Monitor has dead pixels.
- Mouse buttons are not responding correctly.
- Keyboard has damaged keys.
- Ethernet cable is loose.
- An application will not open.
- The screen shows visual damage.

### Step 4: Submit a manual issue report

1. Select the affected item.
2. Choose or confirm the problem type.
3. Enter a clear description.
4. Submit the report.

Useful descriptions identify:

- What device or software is affected.
- What happened.
- When it happened.
- Whether the issue is constant or intermittent.

Example:

```text
The left mouse button sometimes double-clicks when pressed once.
```

### Step 5: Use the computer

After authentication and the required checks, continue with the laboratory
activity. Syswatch can remain hidden in the system tray while monitoring
continues in the background.

Do not exit Syswatch from Task Manager. Doing so stops monitoring and prevents
the session from being recorded correctly.

### Step 6: Respond to a peripheral warning

If Syswatch detects a disconnected keyboard, mouse, or monitor:

1. Read the warning and identify the affected device.
2. Check the cable or USB connection.
3. Reconnect the device securely.
4. Wait for the automatic recheck.
5. Continue working after the warning disappears.

The student remains logged in during a recoverable peripheral problem.

Do not repeatedly reconnect a damaged device. If the warning remains, use
another workstation and contact ITSO.

### Step 7: Respond to `PC BROKEN`

If Syswatch displays a serious `PC BROKEN` warning:

1. Stop using the workstation.
2. Do not restart, open, or repair the computer yourself.
3. Save school work only if it is safe to do so.
4. Use another available workstation.
5. Contact ITSO and provide the room and PC number.

A serious warning may indicate a CPU, RAM, disk, storage, or important network
problem that requires staff assistance.

### Step 8: Log out

At the end of the laboratory session:

1. Save and close personal school work.
2. Return to Syswatch.
3. Select **Logout**.
4. Wait for the student login screen.

Logging out allows Syswatch to record the end of the session and prepares the
workstation for the next student.

---

## 5. Administrator PC Configuration Tutorial

Use this only when installing Syswatch on a new PC or changing the PC's room or
assignment.

1. Open the Student PC App.
2. Press `Ctrl + Shift + A`.
3. Enter the administrator email and password.
4. Open **Manage PC Configuration**.
5. Enter the correct room.
6. Enter the correct PC number.
7. Review the workstation identity.
8. Save the configuration.
9. Restart Syswatch and confirm the saved assignment.

Do not share the administrator password with students. Do not use the shortcut
to perform normal student login.

---

## 6. How Offline Mode Works

Syswatch separates local operation from online synchronization.

| Situation | Syswatch behavior |
|---|---|
| Internet is available | Authenticates, refreshes accounts, and syncs pending records |
| Internet is unavailable | Uses downloaded accounts and saves new records in SQLite |
| Internet returns | Automatically sends pending records to Firebase |
| A sync attempt fails | Keeps the local record pending and retries later |
| The app is hidden | Monitoring and automatic synchronization continue |

Offline records are not discarded when synchronization fails. They remain
stored locally until Firebase accepts them.

Data that may be synchronized includes:

- Login and logout logs
- Fault reports
- PC and peripheral status
- Maintenance records
- Workstation status and heartbeat
- Last known student information

---

## 7. Warning Types

| Warning | Meaning | Student action |
|---|---|---|
| Recoverable peripheral warning | Keyboard, mouse, or monitor was disconnected or stopped responding | Check and reconnect the device, then wait for automatic recovery |
| Ethernet/LAN warning | The wired network connection is unavailable | Check the cable, use another PC if required, and contact ITSO |
| `PC BROKEN` | A serious workstation health problem was detected | Stop using the PC, move to another workstation, and contact ITSO |
| Manual report confirmation | The student's report was saved locally or online | Continue only if the workstation remains safe to use |

---

## 8. Records and Information Managed by Syswatch

Syswatch can maintain the following information:

- Authorized user profiles
- Laboratory rooms
- PC assignments
- Permanent workstation identities
- Login and logout logs
- Fault reports
- Maintenance logs
- PC status records
- Workstation heartbeat or last check
- Last known student
- Local synchronization state

Students only see the controls required for authentication, peripheral
confirmation, problem reporting, and logout.

---

## 9. Demonstration Guide

Use this short sequence when demonstrating Syswatch to an instructor or panel.

1. Start the Windows PC and show that Syswatch opens automatically.
2. Show the configured room and PC identity.
3. Log in with a student account.
4. Show the keyboard, mouse, monitor, and Ethernet/LAN check.
5. Unplug the keyboard.
6. Wait for the warning and show that the student remains logged in.
7. Reconnect the keyboard and show that the warning clears automatically.
8. Submit a visible or software issue report.
9. Disconnect the internet.
10. Create another report and explain that SQLite stores it as pending.
11. Reconnect the internet and show the automatic Firebase synchronization.
12. Press `Ctrl + Shift + A` and show the protected administrator login.
13. Explain that full ITSO and administrative management is kept in the
    separate Staff application.
14. Log out and show that the workstation is ready for the next student.

---

## 10. Troubleshooting

### Syswatch does not start automatically

1. Open Syswatch manually from the Start menu.
2. Restart the PC.
3. Confirm that the installed application, rather than a Flutter debug build,
   is registered at startup.
4. Ask an administrator to reinstall or repair the application if necessary.

### Offline login does not work

1. Connect the PC to the internet.
2. Open Syswatch and wait for student accounts to refresh.
3. Confirm that the student account is active.
4. Disconnect the internet and test again.

Offline login cannot work on a new installation until the required account has
been downloaded at least once.

### A warning remains after reconnecting a device

1. Reconnect the device securely.
2. Wait for another monitoring check.
3. Try another known-working USB port if permitted.
4. Do not change Windows drivers or open the computer.
5. Move to another workstation and contact ITSO if the warning remains.

### Records do not appear in Firebase

1. Confirm that the PC has working internet.
2. Keep Syswatch running.
3. Allow automatic synchronization to retry.
4. Check whether Firebase access or security rules are blocking writes.
5. Do not delete the local SQLite database because pending records may still be
   stored there.

### `Ctrl + Shift + A` does not open PC Configuration

1. Confirm that Syswatch is running.
2. Bring the application to the foreground.
3. Press all three keys together.
4. Restart Syswatch if the shortcut service did not initialize.
5. Contact the system administrator if the problem continues.

---

## 11. Important Usage Rules

- Keep Syswatch running during every laboratory session.
- Do not give administrator credentials to students.
- Do not assign the same PC identity to multiple workstations.
- Do not delete the SQLite database while records are pending.
- Do not remove or repair internal PC components.
- Report recurring warnings to ITSO.
- Use one shared Windows laboratory account if the workstation is designed to
  keep one shared local Syswatch database.

---

## 12. Quick Feature Summary

- Windows laboratory PC application
- Startup and kiosk-style student access
- Student authentication
- Offline login through SQLite
- Automatic Firebase synchronization
- Keyboard, mouse, monitor, and Ethernet/LAN monitoring
- CPU, RAM, disk, and storage health checks
- Visible damage and software issue reporting
- Recoverable peripheral warnings
- Automatic recheck after reconnection
- Serious `PC BROKEN` warning
- Background and system-tray monitoring
- Workstation identity and heartbeat
- Last known student tracking
- Protected `Ctrl + Shift + A` administrator shortcut
- Separate Student PC and Staff applications

---

## 13. System Purpose

Syswatch helps protect laboratory computers and improve accountability by
combining student access control, automatic workstation monitoring, manual issue
reporting, offline data storage, and online synchronization in one system.
