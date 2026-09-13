@echo off
REM ===========================================================================
REM  view_waves.bat - opens a waveform in GTKWave.
REM
REM  Picks the .vcd file for you. The build also produces .vvp files, which are
REM  compiled simulation binaries rather than waveforms - handing one of those
REM  to GTKWave gives "No symbols in VCD file", which says nothing about the
REM  actual mistake.
REM ===========================================================================

setlocal
cd /d "%~dp0"

set "GTKWAVE=C:\iverilog\gtkwave\bin\gtkwave.exe"

if not exist "%GTKWAVE%" (
    echo [X] GTKWave not found at %GTKWAVE%
    echo     It ships with Icarus Verilog:  winget install Icarus.Verilog
    pause
    exit /b 1
)

if not exist "sim\alu_tb.vcd" (
    echo [!] No waveforms yet - run run_all.bat first.
    pause
    exit /b 1
)

echo.
echo  Which waveform?
echo.
echo    1 - ALU              ^(a, b, opcode, result, carry, overflow^)
echo    2 - Sequence detector ^(clk, din, state, detected^)
echo.
set "choice="
set /p "choice=Enter 1 or 2: "

if "%choice%"=="2" (
    start "" "%GTKWAVE%" "sim\seq_tb.vcd"
) else (
    start "" "%GTKWAVE%" "sim\alu_tb.vcd"
)

echo.
echo  GTKWave is opening. Drag signals from the left panel into the wave area.
echo.
timeout /t 3 >nul
