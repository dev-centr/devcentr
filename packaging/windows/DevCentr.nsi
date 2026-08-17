; DevCentr per-user setup. Compile from CI / scripts/package-windows.ps1:
;   makensis /DPAYLOAD_DIR=... /DOUT_FILE=... /DPRODUCT_VERSION=... DevCentr.nsi
!include "MUI2.nsh"

!ifndef PRODUCT_NAME
  !define PRODUCT_NAME "DevCentr"
!endif
!ifndef PRODUCT_VERSION
  !define PRODUCT_VERSION "0.0.0"
!endif
!ifndef PRODUCT_PUBLISHER
  !define PRODUCT_PUBLISHER "DevCentr.org"
!endif
!ifndef PAYLOAD_DIR
  !error "PAYLOAD_DIR must be defined (folder containing DevCentr.exe)"
!endif
!ifndef OUT_FILE
  !define OUT_FILE "DevCentr-windows-x64-setup.exe"
!endif

Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "${OUT_FILE}"
InstallDir "$LOCALAPPDATA\Programs\${PRODUCT_NAME}"
InstallDirRegKey HKCU "Software\${PRODUCT_PUBLISHER}\${PRODUCT_NAME}" "InstallDir"
RequestExecutionLevel user
Unicode true
SetCompressor lzma
ShowInstDetails show

!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Install"
  SetOutPath "$INSTDIR"
  File "${PAYLOAD_DIR}/DevCentr.exe"
  File "${PAYLOAD_DIR}/libfreetype-6.dll"
  File /nonfatal "${PAYLOAD_DIR}/LICENSE"

  CreateDirectory "$SMPROGRAMS\${PRODUCT_NAME}"
  CreateShortCut "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME}.lnk" "$INSTDIR\DevCentr.exe"

  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" \
    "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" \
    "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" \
    "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" \
    "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" \
    "DisplayIcon" "$INSTDIR\DevCentr.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" \
    "InstallLocation" "$INSTDIR"
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" \
    "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" \
    "NoRepair" 1
  WriteRegStr HKCU "Software\${PRODUCT_PUBLISHER}\${PRODUCT_NAME}" "InstallDir" "$INSTDIR"
SectionEnd

Section "Uninstall"
  Delete "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME}.lnk"
  RMDir "$SMPROGRAMS\${PRODUCT_NAME}"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir /r "$INSTDIR"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
  DeleteRegKey HKCU "Software\${PRODUCT_PUBLISHER}\${PRODUCT_NAME}"
SectionEnd
