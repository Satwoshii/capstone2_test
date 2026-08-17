#define MyAppName "Syswatch Student"
#define MyAppVersion "2.5.7"
#define MyAppPublisher "NU Clark"
#define MyAppExeName "Syswatch.exe"
#define VCRedistFile "VC_redist.x64.exe"

; Save this file inside the Student Flutter project's installer folder:
;   capstone2_test-master\installer\Syswatch_Student_Installer_v2.7.1.iss
; The Flutter project root must be one folder above this script.

#define ProjectRoot AddBackslash(SourcePath) + ".."
#define ReleaseDir AddBackslash(ProjectRoot) + "build\windows\x64\runner\Release"
#define VCRedistPath AddBackslash(SourcePath) + VCRedistFile

#if !FileExists(AddBackslash(ProjectRoot) + "pubspec.yaml")
  #error "pubspec.yaml was not found. Put this ISS file inside the Student project's installer folder."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "windows\CMakeLists.txt")
  #error "The Windows project files were not found. Run 'flutter create --platforms=windows .' first."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\screens\student\student_login_screen.dart")
  #error "The Syswatch Student login screen was not found. Check that this is the Student project."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\services\auth_service.dart")
  #error "auth_service.dart was not found. Copy the latest Student edited files into the project first."
#endif

; Locate Flutter. Add another path here if Flutter is installed elsewhere.
#if FileExists("C:\Flutter\src\flutter\bin\flutter.bat")
  #define FlutterExe "C:\Flutter\src\flutter\bin\flutter.bat"
#elif FileExists("C:\src\flutter\bin\flutter.bat")
  #define FlutterExe "C:\src\flutter\bin\flutter.bat"
#else
  #define FlutterExe "flutter.bat"
#endif

; Always rebuild so the installer never packages an old Release folder.
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
  #error "Syswatch.exe was not created. Check BINARY_NAME in windows\CMakeLists.txt."
#endif

[Setup]
; Keep this AppId unchanged so this installer upgrades earlier Student versions.
AppId={{6CFA4ED7-15B8-4FD7-9A4D-910CC54BCE73}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}

DefaultDirName={autopf}\Syswatch Student
DefaultGroupName=Syswatch Student
DisableProgramGroupPage=yes
AllowNoIcons=yes

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
UsePreviousAppDir=yes

VersionInfoVersion=2.7.1.0
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

; Optional: place VC_redist.x64.exe beside this ISS file to bundle it.
#if FileExists(VCRedistPath)
Source: "{#VCRedistPath}"; DestDir: "{tmp}"; Flags: deleteafterinstall
#endif

[Icons]
Name: "{autoprograms}\Syswatch Student"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\Syswatch Student"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon
Name: "{autostartup}\Syswatch Student"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: startup

[Run]
#if FileExists(VCRedistPath)
Filename: "{tmp}\{#VCRedistFile}"; Parameters: "/install /passive /norestart"; StatusMsg: "Installing Microsoft Visual C++ Runtime..."; Flags: waituntilterminated
#endif
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Syswatch Student"; WorkingDir: "{app}"; Flags: postinstall nowait skipifsilent runasoriginaluser

[UninstallDelete]
; Only installed program files are removed. SQLite, configuration, and logs
; stored under the Windows user profile are deliberately preserved.
Type: filesandordirs; Name: "{app}"
