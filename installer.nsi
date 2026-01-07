; NSIS installer for Visualizador SIOP

;--------------------------------
; Propiedades del producto
;--------------------------------

!define APP_NAME "Visualizador SIOP"
!define APP_VERSION "1.0.0"
!define COMPANY_NAME "INIDEP"
!define EXE_NAME "visualizador_siop.exe"

Name "${APP_NAME}"
OutFile "installer\\InstalarVisualizadorSIOP.exe"
InstallDir "$PROGRAMFILES64\\${APP_NAME}"
InstallDirRegKey HKLM "Software\\${APP_NAME}" "Install_Dir"
RequestExecutionLevel admin

;--------------------------------
; Interfaz gráfica (MUI2)
;--------------------------------

!include "MUI2.nsh"

!define MUI_ICON "windows\\runner\\resources\\app_icon.ico"
!define MUI_UNICON "windows\\runner\\resources\\app_icon.ico"

!define MUI_PRODUCT_NAME "${APP_NAME}"
!define MUI_WELCOMEPAGE_TITLE "${APP_NAME}"
!define MUI_WELCOMEPAGE_TEXT "Bienvenido a la instalación de ${APP_NAME}"
!define MUI_FINISHPAGE_TITLE "Instalación completada"
!define MUI_FINISHPAGE_TEXT "${APP_NAME} se ha instalado correctamente en este equipo."

!define MUI_UNWELCOMEPAGE_TITLE "Desinstalación de ${APP_NAME}"
!define MUI_UNWELCOMEPAGE_TEXT "Este asistente eliminará ${APP_NAME} de su sistema."
!define MUI_UNFINISHPAGE_TITLE "Desinstalación completada"
!define MUI_UNFINISHPAGE_TEXT "${APP_NAME} ha sido eliminado."

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

;--------------------------------
; Idioma
;--------------------------------

!insertmacro MUI_LANGUAGE "Spanish"

;--------------------------------
; Sección de instalación
;--------------------------------

Section "Install"
  SetOutPath $INSTDIR

  ; Archivos principales
  File "docs\\LICENSE.txt"
  File /r "build\\windows\\x64\\runner\\Release\\"

  ; Accesos directos
  CreateDirectory "$SMPROGRAMS\\${APP_NAME}"
  CreateShortCut "$SMPROGRAMS\\${APP_NAME}\\${APP_NAME}.lnk" "$INSTDIR\\${EXE_NAME}"
  CreateShortCut "$DESKTOP\\${APP_NAME}.lnk" "$INSTDIR\\${EXE_NAME}"
  CreateShortCut "$SMPROGRAMS\\${APP_NAME}\\Desinstalar ${APP_NAME}.lnk" "$INSTDIR\\uninstall.exe"

  ; Registro de desinstalador
  WriteRegStr HKLM "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\${APP_NAME}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKLM "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\${APP_NAME}" "UninstallString" '"$INSTDIR\\uninstall.exe"'
  WriteRegDWORD HKLM "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\${APP_NAME}" "NoModify" 1
  WriteRegDWORD HKLM "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\${APP_NAME}" "NoRepair" 1
  WriteUninstaller "$INSTDIR\\uninstall.exe"
SectionEnd

;--------------------------------
; Sección de desinstalación
;--------------------------------

Section "Uninstall"
  Delete "$INSTDIR\\uninstall.exe"
  RMDir /r "$INSTDIR"

  Delete "$SMPROGRAMS\\${APP_NAME}\\${APP_NAME}.lnk"
  Delete "$DESKTOP\\${APP_NAME}.lnk"
  RMDir "$SMPROGRAMS\\${APP_NAME}"

  DeleteRegKey HKLM "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\${APP_NAME}"
  DeleteRegKey HKLM "Software\\${APP_NAME}"
SectionEnd
