; Inno Setup 6 - instalador do Consultas (Win64, instalacao por usuario ou para todos)
; Gerado a partir de: dist\Consultas\  (PyInstaller onedir)
;   ISCC.exe installer\Consultas.iss
; Saida: installer\output\ConsultasSetup.exe

#define MyAppName "Consultas"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Realtec"
#define MyAppExeName "Consultas.exe"

[Setup]
AppId={{6F1B7C52-3D0E-4C1A-9E57-C05A17A50011}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; padrao: por usuario (%LOCALAPPDATA%\Programs\Consultas, sem admin). O usuario pode escolher "todos os usuarios".
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=output
OutputBaseFilename=ConsultasSetup
SetupIconFile=..\assets\Consultas_Icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\dist\Consultas\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
