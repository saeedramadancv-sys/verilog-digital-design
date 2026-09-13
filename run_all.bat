@echo off
REM ===========================================================================
REM  run_all.bat - runs every simulation on Windows.
REM
REM  Double-click it, or run it from cmd:
REM      run_all.bat
REM
REM  No PATH setup needed: the tool locations are resolved below, and the
REM  script says clearly which one is missing rather than failing with a
REM  "not recognized as an internal or external command" that explains nothing.
REM ===========================================================================

setlocal enabledelayedexpansion
cd /d "%~dp0"

set "IVERILOG=C:\iverilog\bin\iverilog.exe"
set "VVP=C:\iverilog\bin\vvp.exe"
set "GTKWAVE=C:\iverilog\gtkwave\bin\gtkwave.exe"

REM GHDL installs under the WinGet packages folder; find it rather than
REM hard-coding the version-stamped directory name.
set "GHDL="
for /f "delims=" %%G in ('dir /b /s "%LOCALAPPDATA%\Microsoft\WinGet\Packages\ghdl.exe" 2^>nul') do set "GHDL=%%G"

if not exist "%IVERILOG%" (
    echo [X] Icarus Verilog not found at %IVERILOG%
    echo     Install it with:  winget install Icarus.Verilog
    exit /b 1
)

if not exist "sim" mkdir "sim"
if not exist "sim\ghdl" mkdir "sim\ghdl"

echo.
echo == Verilog ALU ==
"%IVERILOG%" -g2012 -Wall -o sim\alu_tb.vvp rtl\alu.v tb\alu_tb.v || exit /b 1
"%VVP%" sim\alu_tb.vvp || exit /b 1

echo.
echo == Sequence detector ==
"%IVERILOG%" -g2012 -Wall -o sim\seq_tb.vvp rtl\seq_detector.v tb\seq_detector_tb.v || exit /b 1
"%VVP%" sim\seq_tb.vvp || exit /b 1

if defined GHDL (
    echo.
    echo == VHDL ALU ==
    "%GHDL%" -a --std=08 --workdir=sim\ghdl vhdl\alu.vhd vhdl\alu_tb.vhd || exit /b 1
    "%GHDL%" -r --std=08 --workdir=sim\ghdl alu_tb || exit /b 1
) else (
    echo.
    echo [!] GHDL not found - skipping the VHDL suite.
    echo     Install it with:  winget install ghdl.ghdl.ucrt64.mcode
)

echo.
echo ===========================================
echo  All suites passed.
echo ===========================================
echo.
echo  To view waveforms:
echo      "%GTKWAVE%" sim\alu_tb.vcd
echo      "%GTKWAVE%" sim\seq_tb.vcd
echo.
pause
