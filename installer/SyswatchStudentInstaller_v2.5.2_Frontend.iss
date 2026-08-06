#define MyAppName "Syswatch Student"
#define MyAppVersion "2.5.2"
#define MyAppPublisher "NU Clark"
#define MyAppExeName "Syswatch.exe"
#define VCRedistFile "VC_redist.x64.exe"

; This script must be stored in the project's "installer" folder.
#define ProjectRoot AddBackslash(SourcePath) + ".."
#define ReleaseDir AddBackslash(ProjectRoot) + "build\windows\x64\runner\Release"

; Stop immediately if this is not the latest Syswatch Flutter project.
#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\student\student_login_screen.dart")
  #error "student_login_screen.dart was not found. Put this .iss file inside the project's installer folder."
#endif

; Use the Flutter SDK path from this Syswatch development PC when available.
; Otherwise, fall back to flutter.bat from the Windows PATH.
#if FileExists("C:\Flutter\src\flutter\bin\flutter.bat")
  #define FlutterExe "C:\Flutter\src\flutter\bin\flutter.bat"
#else
  #define FlutterExe "flutter.bat"
#endif

; Always rebuild the current Flutter source before packaging it.
; This prevents an old build\windows\...\Release folder from being reused.
#define FlutterCleanExitCode Exec(FlutterExe, "clean", ProjectRoot, 1, 1)
#if FlutterCleanExitCode != 0
  #error "flutter clean failed. Check the Flutter SDK path, then compile this script again."
#endif

#define FlutterPackagesExitCode Exec(FlutterExe, "pub get", ProjectRoot, 1, 1)
#if FlutterPackagesExitCode != 0
  #error "flutter pub get failed. Fix the reported dependency error, then compile this script again."
#endif

#define FlutterBuildExitCode Exec(FlutterExe, "build windows --release", ProjectRoot, 1, 1)
#if FlutterBuildExitCode != 0
  #error "Flutter Windows release build failed. Fix the reported build error, then compile this script again."
#endif

#if !FileExists(AddBackslash(ReleaseDir) + MyAppExeName)
  #error "The Flutter build finished without creating build\windows\x64\runner\Release\Syswatch.exe."
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
RestartApplications=no
RestartIfNeededByRun=no
SetupLogging=yes

VersionInfoVersion=2.5.2.0
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
; Packages the fresh Flutter build created above, including the redesigned UI.
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#VCRedistFile}"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{autoprograms}\Syswatch Student"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\Syswatch Student"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon
Name: "{autostartup}\Syswatch Student"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: startup

[Run]
Filename: "{tmp}\{#VCRedistFile}"; Parameters: "/install /passive /norestart"; StatusMsg: "Installing Microsoft Visual C++ Runtime..."; Flags: waituntilterminated
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Syswatch Student"; WorkingDir: "{app}"; Flags: postinstall nowait skipifsilent runasoriginaluser

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
