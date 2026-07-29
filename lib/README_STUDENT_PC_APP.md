# Student PC App

This app remains the kiosk/startup app installed on laboratory computers.

Flow:
- Startup -> Student Authentication
- Student login and peripheral confirmation
- One global hardware monitor before login, during sessions, and in the tray
- Yellow minor warnings for keyboard, mouse, and monitor problems
- Red PC BROKEN warnings for Ethernet and internal hardware problems
- Automatic recovery without ending the current student session
- Auto sync to Firebase

Hidden admin-only local configuration:
- Press Ctrl + Shift + A on Student Authentication
- Admin login opens PC Configuration only

The ITSO/Admin management dashboard is now moved to the separate Staff Admin App.
