; Instalador de Windows (Inno Setup 6). Lo compila el workflow de GitHub:
;   ISCC.exe /DAppVersion=0.1.0 /DSourceDir=<carpeta Release> /DOutputDir=<salida> /DOutputBase=<nombre> PKArkTools.iss
; Se instala por usuario (sin pedir permisos de administrador). Sin firmar:
; SmartScreen avisa la primera vez («Más información → Ejecutar de todas formas»).

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif
#ifndef OutputBase
  #define OutputBase "PKArkTools-setup"
#endif

[Setup]
AppId={{6B0B7A52-3C1E-4F7B-9E54-5A2D7C1F0A11}
AppName=PKArkTools
AppVersion={#AppVersion}
AppVerName=PKArkTools {#AppVersion}
AppPublisher=PKArkTools
AppPublisherURL=https://github.com/Rodriqe/PKArkTools
AppSupportURL=https://github.com/Rodriqe/PKArkTools/issues
DefaultDirName={autopf}\PKArkTools
DefaultGroupName=PKArkTools
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\PKArkTools.exe
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBase}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\PKArkTools"; Filename: "{app}\PKArkTools.exe"
Name: "{autodesktop}\PKArkTools"; Filename: "{app}\PKArkTools.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\PKArkTools.exe"; Description: "{cm:LaunchProgram,PKArkTools}"; Flags: nowait postinstall skipifsilent
