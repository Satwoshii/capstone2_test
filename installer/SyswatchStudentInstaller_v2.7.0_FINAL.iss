#define MyAppName "Syswatch Student"
#define MyAppVersion "2.7.0"
#define MyAppPublisher "NU Clark"
#define MyAppExeName "Syswatch.exe"
#define VCRedistFile "VC_redist.x64.exe"

; ============================================================
; SYSWATCH STUDENT v2.7.0 - FINAL INSTALLER
; Put this file inside:
;   capstone2_test-master\installer\
; Keep VC_redist.x64.exe beside this file.
; ============================================================

#define ProjectRoot AddBackslash(SourcePath) + ".."
#define ReleaseDir AddBackslash(ProjectRoot) + "build\windows\x64\runner\Release"

; ------------------------------------------------------------
; Validate that this is the correct Student project
; ------------------------------------------------------------
#if !FileExists(AddBackslash(ProjectRoot) + "pubspec.yaml")
  #error "pubspec.yaml was not found. Put this .iss file inside the project's installer folder."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\student\student_login_screen.dart")
  #error "Syswatch Student login source was not found. Check the project folder."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\models\active_student_session.dart")
  #error "The Syswatch v2.7.0 single active student session source was not found."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\services\student_session_service.dart")
  #error "The Syswatch v2.7.0 student session service was not found."
#endif

#if !FileExists(AddBackslash(SourcePath) + VCRedistFile)
  #error "VC_redist.x64.exe was not found beside this .iss file."
#endif

; ------------------------------------------------------------
; Find Flutter
; ------------------------------------------------------------
#if FileExists("C:\Flutter\src\flutter\bin\flutter.bat")
  #define FlutterExe "C:\Flutter\src\flutter\bin\flutter.bat"
#elif FileExists("C:\src\flutter\bin\flutter.bat")
  #define FlutterExe "C:\src\flutter\bin\flutter.bat"
#else
  #define FlutterExe "flutter.bat"
#endif

; ------------------------------------------------------------
; Always build the CURRENT source before packaging.
; This prevents an old Release folder from being installed.
; ------------------------------------------------------------
#define FlutterCleanExitCode Exec(FlutterExe, "clean", ProjectRoot, 1, 1)
#if FlutterCleanExitCode != 0
  #error "flutter clean failed. Check Flutter and Visual Studio Desktop development with C++."
#endif

#define FlutterPackagesExitCode Exec(FlutterExe, "pub get", ProjectRoot, 1, 1)
#if FlutterPackagesExitCode != 0
  #error "flutter pub get failed. Fix dependency errors before creating the installer."
#endif

#define FlutterBuildExitCode Exec(FlutterExe, "build windows --release", ProjectRoot, 1, 1)
#if FlutterBuildExitCode != 0
  #error "Flutter Windows release build failed. Fix the Windows build error and try again."
#endif

#if !FileExists(AddBackslash(ReleaseDir) + MyAppExeName)
  #error "Syswatch.exe was not created in build\windows\x64\runner\Release."
#endif

; ============================================================
; INSTALLER SETTINGS
; ============================================================
[Setup]
; Keep this AppId unchanged so newer versions upgrade the same Student app.
AppId={{6CFA4ED7-15B8-4FD7-9A4D-910CC54BCE73}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}

DefaultDirName={autopf}\Syswatch Student
DefaultGroupName=Syswatch Student
DisableProgramGroupPage=yes

OutputDir=output
OutputBaseFilename=Syswatch_Student_Setup_v{#MyAppVersion}
SetupIconFile={#ProjectRoot}\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

Compression=lzma2
SolidCompression=yes
WizardStyle=modern

PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0

CloseApplications=yes
CloseApplicationsFilter={#MyAppExeName}
RestartApplications=no
RestartIfNeededByRun=no
SetupLogging=yes

VersionInfoVersion=2.7.0.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Syswatch Student Installer
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked
Name: "startup"; Description: "Start Syswatch Student when Windows starts"; GroupDescription: "Startup:"; Flags: checkedonce

[Files]
; IMPORTANT: Flutter Windows apps require the ENTIRE Release folder,
; not only Syswatch.exe.
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Install the Visual C++ x64 runtime required by Flutter Windows.
Source: "{#VCRedistFile}"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{autoprograms}\Syswatch Student"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\Syswatch Student"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon
Name: "{autostartup}\Syswatch Student"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: startup

[Run]
Filename: "{tmp}\{#VCRedistFile}"; Parameters: "/install /passive /norestart"; StatusMsg: "Installing Microsoft Visual C++ Runtime..."; Flags: waituntilterminated
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Syswatch Student"; WorkingDir: "{app}"; Flags: postinstall nowait skipifsilent runasoriginaluser

[UninstallDelete]
; Only remove the installed program files.
; Syswatch local/offline data stored outside Program Files is preserved.
Type: filesandordirs; Name: "{app}"
