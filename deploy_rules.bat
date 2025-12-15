@echo off
echo ============================================
echo   DEPLOY FIREBASE FIRESTORE RULES
echo ============================================
echo.

REM Check if Firebase CLI is installed
where firebase >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Firebase CLI chua duoc cai dat!
    echo.
    echo Cai dat bang lenh: npm install -g firebase-tools
    echo.
    pause
    exit /b 1
)

echo [1/3] Dang kiem tra Firebase login...
firebase login:list >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [INFO] Chua dang nhap. Dang mo trinh duyet...
    firebase login
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Dang nhap that bai!
        pause
        exit /b 1
    )
)

echo [2/3] Dang deploy Firestore rules...
firebase deploy --only firestore:rules --project quanly-e5ea6

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ============================================
    echo   THANH CONG! Rules da duoc deploy.
    echo ============================================
    echo.
    echo Ban co the:
    echo   1. Restart Flutter app (nhan 'R' trong terminal)
    echo   2. Thu lai chuc nang gui yeu cau muon sach
    echo.
) else (
    echo.
    echo [ERROR] Deploy that bai! Kiem tra lai:
    echo   - File firestore.rules co ton tai khong?
    echo   - Firebase project ID co dung khong?
    echo.
)

pause
