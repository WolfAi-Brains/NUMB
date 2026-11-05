; Compile with Inno Setup 6: iscc NUMB-Setup.iss
; Output: Install\Output\NUMB-Setup-1.4.6.exe
; Per-user install — no administrator required.

#define MyAppName "NUMB"
#define MyAppVersion "1.4.6"
#define MyAppPublisher "WolfAi"
#define MyAppURL "mailto:yankolobo@gmail.com"

[Setup]
AppId={{A7E3C9B1-4F2D-4A8B-B8E1-0D5F3A2C9E01}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppSupportURL={#MyAppURL}
DefaultDirName={localappdata}\WolfAi\NUMB
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputBaseFilename=NUMB-Setup-{#MyAppVersion}
OutputDir=Output
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\numb.ico
CloseApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\number-ops\NUMB.ahk"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\number-ops\numb.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\number-ops\Start NUMB.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\number-ops\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "portable\AutoHotkey64.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\Start NUMB.bat"; IconFilename: "{app}\numb.ico"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\Start NUMB.bat"; Description: "Start {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: files; Name: "{app}\numb.ini"
