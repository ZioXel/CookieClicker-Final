[Setup]
AppName=Cookie Clicker
AppVersion=1.0
DefaultDirName={pf}\CookieClicker
DefaultGroupName=Cookie Clicker
OutputDir=output
OutputBaseFilename=CookieClickerSetup
Compression=lzma
SolidCompression=yes
[Files]
; Include the Flutter app files
Source: "build\windows\x64\runner\Release*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Include the Python executable
Source: "dist\app.exe"; DestDir: "{app}\dist"; Flags: ignoreversion

; Include the assets
Source: "assets\*"; DestDir: "{app}\assets"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Cookie Clicker"; Filename: "{app}\CookieClicker.exe"; IconFilename: "{app}\icons\cookie1.ico"
Name: "{group}\Uninstall Cookie Clicker"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\CookieClicker.exe"; Description: "{cm:LaunchProgram, Cookie Clicker}"; Flags: nowait postinstall skipifsilent