**********
*
* guiclass.prg
*
*****
* Version 0.10
* Copyright (c) 2012 by Rick C. Hodgin
*****
* Last update:
*     November 06, 2012
*****
* Change log:
*     November 06, 2012 - Initial creation
*****
*
* This software is released as Liberty Software under a Repeat License,
* as governed by the Public Benefit License v1.0 or later (PBL).
*
* You are free to use, copy, modify and share this software.  However,
* it can only be released under the PBL version indicated, and every
* project must include a copy of the pbl.txt document for its version
* as is at http://www.libsf.org/licenses/.
*
* For additional information about this project, or to view the license,
* see:
*
*     http://www.libsf.org/
*     http://www.libsf.org/licenses/
*     http://www.visual-freepro.org
*     http://www.visual-freepro.org/blog/
*     http://www.visual-freepro.org/forum/
*     http://www.visual-freepro.org/wiki/
*     http://www.visual-freepro.org/wiki/index.php/PBL
*     http://www.visual-freepro.org/wiki/index.php/Repeat_License
*
* Thank you.  And may The Lord bless you richly as you lift up your life,
* your talents, your gifts, your praise, unto Him.  In Jesus' name I pray.
* Amen.
*
*****




*BINDEVENT(thisForm.hwnd, goHandler.callback,        goHandler, "callbackFromGuiApp")
*BINDEVENT(thisForm.hwnd, goHandler.callbackExiting, goHandler, "callbackFromGuiAppExiting")
DEFINE CLASS guiThreadHandler AS Session
	* These custom messages can be any number 1024 or higher
	callback			= 2000
	callbackExiting		= 2001
	remoteHwnd			= -1
	
	
	* Launches a process quietly (without a command window)
	PROCEDURE launchProcess
	LPARAMETERS tcExecutable, tcCmdLine, tcStartupDirectory
	LOCAL lcProcessInfo
		* Launch the process
		lnResult = CreateProcess("\path\myapp.exe", "-i some -j command -k line_params", 1)
		
		

	* Initial callback from the GUI app
	PROCEDURE callbackFromGuiApp
	LPARAMETERS tnHwnd, tnMsg, tnW, tnL
		remoteHwnd = tnHwnd


	* Callback if the user manually closes the GUI app
	PROCEDURE callbackFromGuiAppExiting
	LPARAMETERS tnHwnd, tnMsg, tnW, tnL

		UNBINDEVENTS(this)
		thisForm.Release
		CLEAR EVENTS
		
ENDDEFINE




* Note:  The following code was taken from West Wind:
*        http://www.west-wind.com/wconnect/weblog/ShowEntry.blog?id=533
************************************************************************
* wwAPI :: Createprocess
****************************************
***  Function: Calls the CreateProcess API to run a Windows application
***    Assume: Gets around RUN limitations which has command line
***            length limits and problems with long filenames.
***            Can do everything EXCEPT REDIRECTION TO FILE!
***      Pass: lcExe - Name of the Exe
***            lcCommandLine - Any command line arguments
***    Return: .t. or .f.
************************************************************************

FUNCTION Createprocess(lcExecutable, lcCommandLine, lnShowWindow)
LOCAL hProcess, cProcessInfo, cStartupInfo
 
DECLARE INTEGER CreateProcess IN kernel32 as _CreateProcess;
    STRING   lpApplicationName,;
    STRING   lpCommandLine,;
    INTEGER  lpProcessAttributes,;
    INTEGER  lpThreadAttributes,;
    INTEGER  bInheritHandles,;
    INTEGER  dwCreationFlags,;
    INTEGER  lpEnvironment,;
    STRING   lpCurrentDirectory,;
    STRING   lpStartupInfo,;
    STRING @ lpProcessInformation

 
cProcessinfo = REPLICATE(CHR(0),128)
cStartupInfo = GetStartupInfo(lnShowWindow)
 
IF !EMPTY(lcCommandLine)
   lcCommandLine = ["] + lcExecutable + [" ]+ lcCommandLine
ELSE
   lcCommandLine = ""
ENDIF
 
lnResult =  _CreateProcess(lcExecutable, lcCommandLine , 0, 0, 1, 0, 0, SYS(5) + CURDIR(), cStartupInfo, @cProcessInfo)
RETURN IIF(lnResult=1,.t.,.f.)

 

FUNCTION getStartupInfo(lnShowWindow)
LOCAL lnFlags
	* creates the STARTUP structure to specify main window
	* properties if a new window is created for a new process
	 
	IF EMPTY(lnShowWindow)
		lnShowWindow = 1
	ENDIF
	 
	*| typedef struct _STARTUPINFO {
	*| DWORD cb; 4
	*| LPTSTR lpReserved; 4
	*| LPTSTR lpDesktop; 4
	*| LPTSTR lpTitle; 4
	*| DWORD dwX; 4
	*| DWORD dwY; 4
	*| DWORD dwXSize; 4
	*| DWORD dwYSize; 4
	*| DWORD dwXCountChars; 4
	*| DWORD dwYCountChars; 4
	*| DWORD dwFillAttribute; 4
	*| DWORD dwFlags; 4
	*| WORD wShowWindow; 2
	*| WORD cbReserved2; 2
	*| LPBYTE lpReserved2; 4
	*| HANDLE hStdInput; 4
	*| HANDLE hStdOutput; 4
	*| HANDLE hStdError; 4
	*| } STARTUPINFO, *LPSTARTUPINFO; total: 68 bytes

	#DEFINE STARTF_USESTDHANDLES	0x0100
	#DEFINE STARTF_USESHOWWINDOW	1
	#DEFINE SW_HIDE					0
	#DEFINE SW_SHOWMAXIMIZED		3
	#DEFINE SW_SHOWNORMAL			1
	 
	lnFlags = STARTF_USESHOWWINDOW
	 
	RETURN	binToChar(80) +;
			binToChar(0) + binToChar(0) + binToChar(0) +;
			binToChar(0) + binToChar(0) + binToChar(0) + binToChar(0) +;
			binToChar(0) + binToChar(0) + binToChar(0) +;
			binToChar(lnFlags) +;
			binToWordChar(lnShowWindow) +;
			binToWordChar(0) + binToChar(0) +;
			binToChar(0) + binToChar(0) + binToChar(0) + REPLICATE(CHR(0),30)
 

************************************************************************
FUNCTION CharToBin(lcBinString,llSigned)
****************************************
***  Function: Binary Numeric conversion routine.
***            Converts DWORD or Unsigned Integer string
***            to Fox numeric integer value.
***      Pass: lcBinString -  String that contains the binary data
***            llSigned    -  if .T. uses signed conversion
***                           otherwise value is unsigned (DWORD)
***    Return: Fox number
************************************************************************
LOCAL m.i, lnWord
	lnWord = 0
	FOR m.i = 1 TO LEN(lcBinString)
		lnWord = lnWord + (ASC(SUBSTR(lcBinString, m.i, 1)) * (2 ^ (8 * (m.i - 1))))
	ENDFOR
	 
	IF llSigned AND lnWord > 0x80000000
		lnWord = lnWord - 1 - 0xFFFFFFFF
	ENDIF
	RETURN lnWord

*  wwAPI :: CharToBin
***********************************************************************
FUNCTION BinToChar(lnValue)
****************************************
***  Function: Creates a DWORD value from a number
***      Pass: lnValue - VFP numeric integer (unsigned)
***    Return: binary string
************************************************************************
LOCAL byte(4)
	If lnValue < 0
	    lnValue = lnValue + 4294967296
	EndIf
	byte(1) = lnValue % 256
	byte(2) = BitRShift(lnValue, 8) % 256
	byte(3) = BitRShift(lnValue, 16) % 256
	byte(4) = BitRShift(lnValue, 24) % 256
	RETURN Chr(byte(1))+Chr(byte(2))+Chr(byte(3))+Chr(byte(4))


*  wwAPI :: BinToChar
************************************************************************
FUNCTION BinToWordChar(lnValue)
****************************************
***  Function: Creates a DWORD value from a number
***      Pass: lnValue - VFP numeric integer (unsigned)
***    Return: binary string
************************************************************************
	RETURN Chr(MOD(m.lnValue,256)) + CHR(INT(m.lnValue/256))
