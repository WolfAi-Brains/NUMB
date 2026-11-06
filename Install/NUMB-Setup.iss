; Compile with Inno Setup 6: iscc NUMB-Setup.iss
; Output: Install\Output\NUMB-Setup-2.1.0.exe
; Per-user install — no administrator required.

#define MyAppName "NUMB"
#define MyAppVersion "2.1.0"
#define MyAppPublisher "WolfAi"
#define MyAppURL "mailto:yankolobo@gmail.com"
#define UninstallRegKey "Software\Microsoft\Windows\CurrentVersion\Uninstall\A7E3C9B1-4F2D-4A8B-B8E1-0D5F3A2C9E01_is1"

[Setup]
AppId={{A7E3C9B1-4F2D-4A8B-B8E1-0D5F3A2C9E01}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppVersion}
VersionInfoVersion={#MyAppVersion}.0
AppPublisher={#MyAppPublisher}
AppSupportURL={#MyAppURL}
DefaultDirName={localappdata}\WolfAi\NUMB
UsePreviousAppDir=yes
DisableDirPage=auto
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
CloseApplications=force
CloseApplicationsFilter=AutoHotkey64.exe
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\number-ops\NUMB.ahk"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\number-ops\numb.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\number-ops\Start NUMB.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\number-ops\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "portable\AutoHotkey64.exe"; DestDir: "{app}"; Flags: ignoreversion

[Tasks]
Name: "startup"; Description: "Start {#MyAppName} when Windows starts"; GroupDescription: "Additional options:"; Flags: checkedonce

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\Start NUMB.bat"; IconFilename: "{app}\numb.ico"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\Start NUMB.bat"; IconFilename: "{app}\numb.ico"; Tasks: startup

[Run]
Filename: "{app}\Start NUMB.bat"; Description: "Start {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: files; Name: "{app}\numb.ini"

[Code]
function GetPreviousDisplayVersion(): String;
begin
  Result := '';
  if not RegQueryStringValue(HKCU, '{#UninstallRegKey}', 'DisplayVersion', Result) then
    RegQueryStringValue(HKLM, '{#UninstallRegKey}', 'DisplayVersion', Result);
end;

function ExistingNumbFolder(): Boolean;
begin
  Result := FileExists(ExpandConstant('{localappdata}\WolfAi\NUMB\NUMB.ahk'));
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
end;

procedure InitializeWizard();
var
  PrevVer: String;
begin
  PrevVer := GetPreviousDisplayVersion();
  if PrevVer <> '' then
  begin
    WizardForm.WelcomeLabel1.Caption := 'Update {#MyAppName}';
    WizardForm.WelcomeLabel2.Caption :=
      'Setup will update {#MyAppName} from version ' + PrevVer + ' to {#MyAppVersion}.' + #13#10 + #13#10 +
      'Program files will be replaced. Your numb.ini settings are kept. NUMB will be closed briefly if it is running.';
  end
  else if ExistingNumbFolder() then
  begin
    WizardForm.WelcomeLabel1.Caption := 'Update {#MyAppName}';
    WizardForm.WelcomeLabel2.Caption :=
      'Setup will update the existing copy in your WolfAi\NUMB folder to {#MyAppVersion}.' + #13#10 + #13#10 +
      'Program files will be replaced. Your numb.ini settings are kept if present.';
  end;

  if FileExists(ExpandConstant('{userstartup}\{#MyAppName}.lnk')) or
     FileExists(ExpandConstant('{userstartup}\{#MyAppName}.bat')) then
    WizardSelectTasks('startup');
end;
