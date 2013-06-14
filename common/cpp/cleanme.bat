@echo off

REM remove all the debug subdirs
echo Removing debug and release folders
for /d /r . %%d in (Debug Release) do @if exist "%%d" echo "%%d" && rd /s/q "%%d"

REM remove all NCB intellisense databases, program databases, and intermediate files
echo Removing intellisense databases
del /s *.ncb
del /s *.pdb
del /s *.manifest
REM All done
