#define MyAppName "Syswatch Student"
#define MyAppVersion "2.3.3"
#define MyAppPublisher "NU Clark"
#define MyAppExeName "Syswatch.exe"
#define VCRedistFile "VC_redist.x64.exe"

[Setup]
AppId={{F4B6E2B3-0D10-4A5E-9C48-51F9EAB8C701}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}

DefaultDirName={autopf}\Syswatch Student
DefaultGroupName=Syswatch Student
DisableProgramGroupPage=yes

OutputDir=output
OutputBaseFilename=Syswatch_Student_Setup_v{#MyAppVersion}

; Enable this only when app_icon.ico is a valid Windows ICO file.
; SetupIconFile=..\assets\tray\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

Compression=lzma2
SolidCompression=yes
WizardStyle=modern

PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

CloseApplications=yes
RestartApplications=no
SetupLogging=yes

VersionInfoVersion=2.3.3.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Syswatch Student PC Installer
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; \
    Description: "Create a desktop shortcut"; \
    GroupDescription: "Additional shortcuts:"; \
    Flags: unchecked

[Files]
; Package the full Flutter Windows release output.
Source: "..\build\windows\x64\runner\Release\*"; \
    DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

; Mandatory Microsoft Visual C++ x64 runtime.
; Compilation intentionally fails when this file is missing.
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

[Run]
; Install or repair the Microsoft Visual C++ runtime before Syswatch starts.
Filename: "{tmp}\{#VCRedistFile}"; \
    Parameters: "/install /quiet /norestart"; \
    StatusMsg: "Installing Microsoft Visual C++ Runtime..."; \
    Flags: waituntilterminated runhidden

; Launch Syswatch only after the runtime installer finishes.
Filename: "{app}\{#MyAppExeName}"; \
    Description: "Launch Syswatch Student"; \
    WorkingDir: "{app}"; \
    Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
