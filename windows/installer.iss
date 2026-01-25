[Setup]
AppId={{73f50bdd-2828-4045-bdc3-927d33518fc0}}
AppName=UtopiaMusic
AppVersion={#AppVersion}
AppPublisher=UtopiaXC
DefaultDirName={pf}\UtopiaMusic
OutputBaseFilename=UtopiaMusic_{#AppVersion}_Windows_x64_setup
ArchitecturesInstallIn64BitMode=x64
Compression=lzma
SolidCompression=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\UtopiaMusic"; Filename: "{app}\UtopiaMusic.exe"
Name: "{commondesktop}\UtopiaMusic"; Filename: "{app}\UtopiaMusic.exe"
