#define AppName "UtopiaMusic"
#define AppVersion "1.0.0"
#define AppPublisher "UtopiaXC"
#define AppURL "https://github.com/UtopiaXC/UtopiaMusic"

#define MyAppExeName "utopia_music.exe"

[Setup]
AppId={{73f50bdd-2828-4045-bdc3-927d33518fc0}}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#AppName}
OutputBaseFilename=UtopiaMusic_{#AppVersion}_Windows_x64_setup
Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
DisableProgramGroupPage=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent