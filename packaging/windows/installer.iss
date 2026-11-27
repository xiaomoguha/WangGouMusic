; 网狗音乐 Windows 安装包脚本（需要 Inno Setup 7）
;
; 平时由 packaging/windows/pack.ps1 调用（它会先跑 windeployqt、拷 MSVC 运行时，再编译本脚本）。
; 也可以手动编译：
;   ISCC /DMyAppVersion=0.8.4 /DPkgDir=<部署好的目录> /DOutputDir=<输出目录> packaging\windows\installer.iss
; 没有通过 /D 传入的值用下面的默认值，路径相对于本文件所在目录。
;
; 注意 AppId 绝对不要动：它是"同一个客户端"的唯一标识，改了老用户升级会变成装出第二个客户端。

#ifndef MyAppVersion
#define MyAppVersion "0.0.0"
#endif
#ifndef SrcDir
#define SrcDir "..\.."
#endif
#ifndef PkgDir
#define PkgDir "..\..\build\Release"
#endif
#ifndef OutputDir
#define OutputDir "..\..\dist"
#endif

#define MyAppName "网狗音乐"
#define MyAppURL "https://music.special520.com/"
#define MyAppExeName "网狗音乐.exe"
#define MyAppAssocName MyAppName + " File"
#define MyAppAssocExt ".myp"
#define MyAppAssocKey StringChange(MyAppAssocName, " ", "") + MyAppAssocExt

[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId={{4514AA45-C477-49C1-84C3-00B6AFAA5E5A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
;AppVerName={#MyAppName} {#MyAppVersion}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
; "ArchitecturesAllowed=x64compatible" specifies that Setup cannot run
; on anything but x64 and Windows 11 on Arm.
ArchitecturesAllowed=x64compatible
; "ArchitecturesInstallIn64BitMode=x64compatible" requests that the install
; be done in "64-bit mode" on x64 or Windows 11 on Arm,
; meaning it should use the native 64-bit Program Files directory and
; the 64-bit view of the registry.
ArchitecturesInstallIn64BitMode=x64compatible
ChangesAssociations=yes
DisableProgramGroupPage=yes
; Uncomment the following line to run in non administrative install mode (install for current user only).
;PrivilegesRequired=lowest
OutputDir={#OutputDir}
; 文件名必须保持 WangGouMusic_<版本>_setup.exe：服务端 checkupdate 的 download_url
; 按 releases/WangGouMusic_<版本>/WangGouMusic_<版本>_setup.exe 拼路径
OutputBaseFilename=WangGouMusic_{#MyAppVersion}_setup
SetupIconFile={#SrcDir}\image\wyymusic.ico
SolidCompression=yes
WizardStyle=modern dynamic

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; windeployqt 部署出的整棵目录树（含子目录）一次装完
Source: "{#PkgDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Registry]
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocExt}\OpenWithProgids"; ValueType: string; ValueName: "{#MyAppAssocKey}"; ValueData: ""; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocKey}"; ValueType: string; ValueName: ""; ValueData: "{#MyAppAssocName}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocKey}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocKey}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
