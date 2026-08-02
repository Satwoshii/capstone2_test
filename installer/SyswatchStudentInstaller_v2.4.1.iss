#define MyAppName "Syswatch Student"
#define MyAppVersion "2.4.1"
#define MyAppPublisher "NU Clark"
#define MyAppExeName "Syswatch.exe"
#define VCRedistFile "VC_redist.x64.exe"

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

UninstallDisplayIcon={app}\{#MyAppExeName}

Compression=lzma2
SolidCompression=yes
WizardStyle=modern

PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

CloseApplications=yes
RestartApplications=no
RestartIfNeededByRun=no
SetupLogging=yes

VersionInfoVersion=2.4.1.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Syswatch Student Installer
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; \
    Description: "Create a desktop shortcut"; \
    GroupDescription: "Additional shortcuts:"; \
    Flags: unchecked

Name: "startup"; \
    Description: "Start Syswatch Student when Windows starts"; \
    GroupDescription: "Startup:"; \
    Flags: checkedonce

[Files]
; Package the ENTIRE Flutter Windows release folder.
Source: "..\build\windows\x64\runner\Release\*"; \
    DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

; Required Microsoft Visual C++ x64 runtime.
Source: "{#VCRedistFile}"; \
    DestDir: "{tmp}"; \
    Flags: deleteafterinstall

[Icons]
Name: "{autoprograms}\Syswatch Student"; \
    Filename: "{app}\{#MyAppExeName}"; \
    WorkingDir: "{app}"

Name: "{autodesktop}\Syswatch Student"; \
    Filename: "{app}\{#MyAppExeName}"; \
    WorkingDir: "{app}"; \
    Tasks: desktopicon

Name: "{autostartup}\Syswatch Student"; \
    Filename: "{app}\{#MyAppExeName}"; \
    WorkingDir: "{app}"; \
    Tasks: startup

[Run]
Filename: "{tmp}\{#VCRedistFile}"; \
    Parameters: "/install /passive /norestart"; \
    StatusMsg: "Installing Microsoft Visual C++ Runtime..."; \
    Flags: waituntilterminated

Filename: "{app}\{#MyAppExeName}"; \
    Description: "Launch Syswatch Student"; \
    WorkingDir: "{app}"; \
    Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
