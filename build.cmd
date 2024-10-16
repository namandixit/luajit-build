@echo off
setlocal enabledelayedexpansion
@chcp 65001>nul

cd %~dp0
set PATH=%CD%;%PATH%

where /q git.exe || (
  echo ERROR: "git.exe" not found
  exit /b 1
)

if exist "%ProgramFiles%\7-Zip\7z.exe" (
  set SZIP="%ProgramFiles%\7-Zip\7z.exe"
) else (
  where /q 7za.exe || (
    echo ERROR: 7-Zip installation or "7za.exe" not found
    exit /b 1
  )
  set SZIP=7za.exe
)

where /Q cl.exe || (
  set __VSCMD_ARG_NO_LOGO=1
  for /f "tokens=*" %%i in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.VisualStudio.Workload.NativeDesktop -property installationPath') do set VS=%%i
  if "!VS!" equ "" (
    echo ERROR: Visual Studio installation not found
    exit /b 1
  )  
  call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" amd64 || exit /b 1

  set MSVC_GENERATOR="Visual Studio 17 2022"
)

set OUTPUT=%~dp0LuaJIT
set SOURCE=%~dp0Source

if not exist %OUTPUT% mkdir %OUTPUT%
pushd %OUTPUT%
mkdir bin
mkdir include
mkdir lib
mkdir lib\static
popd

call :clone %SOURCE%       "https://github.com/LuaJIT/LuaJIT"       v2.1 || exit /b 1

REM Build Dynamic Library
pushd %SOURCE%
pushd src
call msvcbuild.bat debug amalg
popd
popd

REM Copy Dynamic Library
COPY /B /V /Y %SOURCE%\src\lua51.dll  %OUTPUT%\bin\lua51.dll
COPY /B /V /Y %SOURCE%\src\lua51.pdb  %OUTPUT%\bin\lua51.pdb
COPY /B /V /Y %SOURCE%\src\lua51.lib %OUTPUT%\lib\lua51.lib

REM Build Static Library and Executable
pushd %SOURCE%
pushd src
call msvcbuild.bat debug static
popd
popd

REM Copy Static Library and Executable
COPY /B /V /Y %SOURCE%\src\lua51.lib %OUTPUT%\lib\static\lua51.lib
COPY /B /V /Y %SOURCE%\src\lua51.pdb %OUTPUT%\lib\static\lua51.pdb
COPY /B /V /Y %SOURCE%\src\luajit.exe %OUTPUT%\bin\luajit.exe
COPY /B /V /Y %SOURCE%\src\luajit.pdb %OUTPUT%\bin\luajit.pdb

REM Copy headers
COPY /B /V /Y %SOURCE%\src\lua.h     %OUTPUT%\include\lua.h
COPY /B /V /Y %SOURCE%\src\luaconf.h %OUTPUT%\include\luaconf.h
COPY /B /V /Y %SOURCE%\src\lauxlib.h %OUTPUT%\include\lauxlib.h
COPY /B /V /Y %SOURCE%\src\lualib.h  %OUTPUT%\include\lualib.h
COPY /B /V /Y %SOURCE%\src\luajit.h  %OUTPUT%\include\luajit.h
COPY /B /V /Y %SOURCE%\src\lua.hpp   %OUTPUT%\include\lua.hpp

REM Copy license
COPY /B /V /Y %SOURCE%\COPYRIGHT   %OUTPUT%\LICENSE.txt

set /p LuaJIT_COMMIT=<%SOURCE%\.git\refs\heads\v2.1

echo LuaJIT commit %LuaJIT_COMMIT% > %OUTPUT%\commits.txt

rem
rem GitHub actions stuff
rem

if "%GITHUB_WORKFLOW%" neq "" (

  for /F "skip=1" %%D in ('WMIC OS GET LocalDateTime') do (set LDATE=%%D & goto :dateok)
  :dateok
  set OUTPUT_DATE=%LDATE:~0,4%-%LDATE:~4,2%-%LDATE:~6,2%

  echo Creating LuaJIT.zip
  %SZIP% a -y -r -mx=9 "-x^!build" LuaJIT-!OUTPUT_DATE!.zip %OUTPUT% || exit /b 1

  >> %GITHUB_OUTPUT% echo OUTPUT_DATE=!OUTPUT_DATE!

  >> %GITHUB_OUTPUT% echo LuaJIT_COMMIT=%LuaJIT_COMMIT%
)

goto :eof

rem
rem call :clone output_folder "https://..."
rem

:clone
pushd %BUILD%
if exist %1 (
  echo Updating %1
  pushd %1
  call git clean --quiet -fdx
  call git fetch --quiet --no-tags origin %3:refs/remotes/origin/%3 || exit /b 1
  call git reset --quiet --hard origin/%3 || exit /b 1
  popd
) else (
  echo Cloning %1
  call git clone --quiet --branch %3 --no-tags --depth 1 %2 %1 || exit /b 1
)
popd
goto :eof
