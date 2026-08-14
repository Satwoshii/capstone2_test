#define MyAppName "SysWatch Student"
#define MyAppVersion "2.5.5"
#define MyAppPublisher "NU Clark"
#define MyAppExeName "SysWatch.exe"

; Place this file in: YOUR_PROJECT\installer\
; The Flutter project root must be one folder above this file.

#define ProjectRoot AddBackslash(SourcePath) + ".."
#define ReleaseDir AddBackslash(ProjectRoot) + "build\windows\x64\runner\Release"
#define VCRedistPath AddBackslash(SourcePath) + "VC_redist.x64.exe"

#if !FileExists(AddBackslash(ProjectRoot) + "pubspec.yaml")
  #error "pubspec.yaml was not found. Put this ISS file in the project's installer folder."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\student\student_login_screen.dart")
  #error "Student PC source was not found in the project lib folder."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\services\student_session_service.dart")
  #error "student_session_service.dart was not found. Copy the latest lib folder first."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\services\api_client.dart")
  #error "api_client.dart was not found. Copy the latest active-PC-issue fix first."
#endif

; Locate Flutter. Add another path here if Flutter is installed elsewhere.
#if FileExists("C:\Flutter\src\flutter\bin\flutter.bat")
  #define FlutterExe "C:\Flutter\src\flutter\bin\flutter.bat"
#elif FileExists("C:\src\flutter\bin\flutter.bat")
  #define FlutterExe "C:\src\flutter\bin\flutter.bat"
#else
  #define FlutterExe "flutter.bat"
#endif

; Build the current source so an old Release folder is never packaged.
#define FlutterCleanResult Exec(FlutterExe, "clean", ProjectRoot, 1, 1)
#if FlutterCleanResult != 0
  #error "flutter clean failed. Confirm Flutter is installed and available in PATH."
#endif

#define FlutterPubGetResult Exec(FlutterExe, "pub get", ProjectRoot, 1, 1)
#if FlutterPubGetResult != 0
  #error "flutter pub get failed. Fix the dependency error, then compile again."
#endif

#define FlutterBuildResult Exec(FlutterExe, "build windows --release", ProjectRoot, 1, 1)
#if FlutterBuildResult != 0
  #error "Flutter Windows release build failed. Install Visual Studio Desktop development with C++."
#endif

#if !FileExists(AddBackslash(ReleaseDir) + MyAppExeName)
  #error "Syswatch.exe was not created in build\windows\x64\runner\Release. Check BINARY_NAME in windows\CMakeLists.txt."
#endif

[Setup]
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
; A Flutter Windows app requires the entire Release directory.
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Optional: put VC_redist.x64.exe beside this ISS file to bundle it.
#if FileExists(VCRedistPath)
Source: "{#VCRedistPath}"; DestDir: "{tmp}"; Flags: deleteafterinstall
#endif

[Icons]
Name: "{autoprograms}\Syswatch Student"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\Syswatch Student"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon
Name: "{autostartup}\Syswatch Student"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: startup

[Run]
#if FileExists(VCRedistPath)
Filename: "{tmp}\VC_redist.x64.exe"; Parameters: "/install /passive /norestart"; StatusMsg: "Installing Microsoft Visual C++ Runtime..."; Flags: waituntilterminated
#endif
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Syswatch Student"; WorkingDir: "{app}"; Flags: postinstall nowait skipifsilent runasoriginaluser

[UninstallDelete]
; Offline SQLite/configuration data is outside Program Files and is preserved.
Type: filesandordirs; Name: "{app}"
