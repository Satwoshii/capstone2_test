#define MyAppName "Syswatch Student"
#define MyAppVersion "2.7.0"
#define MyAppPublisher "NU Clark"
#define MyAppExeName "Syswatch.exe"
#define VCRedistFile "VC_redist.x64.exe"

; Keep this script inside the project's installer folder.
#define ProjectRoot AddBackslash(SourcePath) + ".."
#define ReleaseDir AddBackslash(ProjectRoot) + "build\windows\x64\runner\Release"

#if !FileExists(AddBackslash(ProjectRoot) + "pubspec.yaml")
  #error "pubspec.yaml was not found. Keep this file inside the project's installer folder."
#endif

#if !FileExists(AddBackslash(ProjectRoot) + "lib\models\active_student_session.dart")
  #error "The v2.7 single-session Student source was not found. Do not package an older project."
#endif

#if !FileExists(AddBackslash(ReleaseDir) + MyAppExeName)
  #error "The Windows Release build is missing. Run CREATE_INSTALLER.bat instead of compiling this file directly."
#endif

#if !FileExists(AddBackslash(SourcePath) + VCRedistFile)
  #error "VC_redist.x64.exe was not found in the installer folder."
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
; Package the entire Flutter Release bundle: EXE, DLLs, plug-ins, and data.
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
; The local SQLite database is stored under the Windows user's Documents path,
; not inside Program Files, so upgrades and uninstall do not erase records.
Type: filesandordirs; Name: "{app}"
