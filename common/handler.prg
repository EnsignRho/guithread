**********
*
* handler.prg
*
*****
* November 07, 2012
* by Rick C. Hodgin
*****




**********
* The master app should create a single object:
*
* SET PROCEDURE TO handler.prg ADDITIVE
* PUBLIC goMultiThread
* goMultiThread = CREATEOBJECT("MultiThreadHandler")
*
*****
	



DEFINE CLASS MultiThreadHandler AS Session
	* Used by master for the master array name
	cMasterArrayName				= SPACE(0)
	nMaxProcessesToSpawn			= 8
	nNextIdNumber					= 1
	nLastLaunchedIdNumber			= 0


	* These custom messages are referenced by both (can be any number 1024 or higher)
	* They are created here instead of constants so it's realized what they relate to.
	* Use as "goMultiThread.nMessageHwnd" for example
	nMessageHwnd				= 2000
	nMessagePercentCompleted	= 2001
	nMessageExiting				= 2002
	nMessagePositionYourself	= 2003
	nMessageSelfTerminate		= 2004

	
	* Constants used to access cMasterArrayName array's columns
	_USED						= 1
	_ID							= 2
	_EXE_NAME					= 3
	_CMD_LINE					= 4
	_START_DIR					= 5
	_REMOTE_HWND				= 6
	_PERCENT					= 7
	_LAUNCHED_OK				= 8
	_LAUNCH_DATETIME			= 9
	_TERMINATION_CODE			= 10
	_MAX_COLUMNS				= 10

	
	**********
	* Bind the events
	*****
		PROCEDURE initializeMaster
		LPARAMETERS toForm
		LOCAL lnI, lcArray
			**********
			* Initialize our array
			*****
				this.cMasterArrayName	= SYS(2015)
				lcArray					= this.cMasterArrayName
				PUBLIC &lcArray
				* Columns are:
				*		1	- logical		- Used?
				*		2	- numeric		- ID number, sequential number assigned at launchProcess
				*		3	- character		- executable name of spawned process
				*		4	- character		- command line parameters
				*		5	- character		- startup directory
				*		6	- numeric		- remoteHwnd, -1=invalid, others=value received on this.nSlaveSaysWithHwnd message
				*		7	- numeric		- percent completed
				*		8	- numeric		- Did CreateProcess() indicate a successful launch of the remote app?
				*		9	- datetime		- The datetime of the launch, can be used to look for hung / failed processe
				DECLARE &lcArray[this.nMaxProcessesToSpawn, this._MAX_COLUMNS]
				FOR lnI = 1 TO this.nMaxProcessesToSpawn
					&lcArray[lnI, this._USED]				= .f.
					&lcArray[lnI, this._ID]					= 0
					&lcArray[lnI, this._EXE_NAME]			= SPACE(0)
					&lcArray[lnI, this._CMD_LINE]			= SPACE(0)
					&lcArray[lnI, this._START_DIR]			= SPACE(0)
					&lcArray[lnI, this._REMOTE_HWND]		= -1
					&lcArray[lnI, this._PERCENT]			= 0
					&lcArray[lnI, this._LAUNCHED_OK]		= .f.
					&lcArray[lnI, this._LAUNCH_DATETIME]	= CTOT("  /  /       :  :  ")
					&lcArray[lnI, this._TERMINATION_CODE]	= 0
				NEXT
		
			**********
			* Bind to the hwnd events we want to listen to
			*****
				BINDEVENT(toForm.hwnd, goMultiThread.nMessageHwnd,				goMultiThread, "slaveSaysHwnd")
				BINDEVENT(toForm.hwnd, goMultiThread.nMessagePercentCompleted,	goMultiThread, "slaveSaysPercentCompleted")
				BINDEVENT(toForm.hwnd, goMultiThread.nMessageExiting,			goMultiThread, "slaveSaysExiting")
	
	
	

	**********
	* They want to send a message to a remote hwnd
	*****
		PROCEDURE SendMessage
		LPARAMETERS tnHwnd, tnMsg, tnW, tnL
		LOCAL lnResult
			DECLARE INTEGER SendMessage IN WIN32API AS SendMessageMultiThread INTEGER hwnd, INTEGER msg, INTEGER w, INTEGER l
			lnResult = SendMessageMultiThread(tnHwnd, tnMsg, tnW, tnL)
			CLEAR DLLS SendMessageMultiThread




	**********
	* They are ready to shut down the master
	*****
		PROCEDURE shutdownMaster
			* Unbind everything
			UNBINDEVENTS(0)
			* We'll leave the array populated as the object will be destroy at some point soon




	**********
	* Launches a process quietly (without a command window)
	* Returns:
	*		(numeric)	- 0=indicates there are zero slots left in which to launch in (nMaxProcessesToSpawn is full of running processes)
	*		(numeric)	- -1=parameter error
	*		(logical)	- The success of the launch, either .t. if launched okay and is running, .f. otherwise
	*****
		PROCEDURE launchSlaveProcess
		LPARAMETERS tcExecutable, tcCmdLine, tcStartupDirectory, tlHideWindowOnLaunch
		LOCAL lnI, lcArray
		
			* Only the tcExecutable parameter IS required
			IF TYPE("tcExecutable") != "C" OR NOT FILE(tcExecutable)
				* A parameter error
				RETURN -1
			ENDIF
			IF TYPE("tcCmdLine") != "C"
				tcCmdLine = SPACE(0)
			ENDIF
			IF TYPE("tcStartupDirectory") != "C"
				tcStartupDirectory = FULLPATH(CURDIR())
			ENDIF

			
			**********
			* Find a slot for the new process in our master spawned array
			*****
				lcArray = this.cMasterArrayName
				FOR lnI = 1 TO this.nMaxProcessesToSpawn
					IF NOT &lcArray[lnI, this._USED]
						* We can populate this slot
						&lcArray[lnI, this._USED]				= .t.
						&lcArray[lnI, this._ID]					= this.nNextIdNumber
						this.nLastLaunchedIdNumber				= this.nNextIdNumber
						&lcArray[lnI, this._EXE_NAME]			= tcExecutable
						&lcArray[lnI, this._CMD_LINE]			= tcCmdLine
						&lcArray[lnI, this._START_DIR]			= tcStartupDirectory
						&lcArray[lnI, this._REMOTE_HWND]		= -1
						&lcArray[lnI, this._PERCENT]			= 0
						&lcArray[lnI, this._LAUNCHED_OK]		= .f.			&& Will be set to true conditoin below
						&lcArray[lnI, this._LAUNCH_DATETIME]	= DATETIME()
						&lcArray[lnI, this._TERMINATION_CODE]	= 0
						
						* Build the rest of the command line
						tcCmdLine = ALLTRIM(tcCmdLine + " " + ALLTRIM(STR(this.nNextIdNumber, 6, 0)) + " " + "foo")
						
						* Increase the id number for the next thing
						this.nNextIdNumber = this.nNextIdNumber + 1
						
						* All done initializing this entry
						EXIT
					ENDIF
				NEXT
			
			
			**********
			* Check for success or failure thus far
			*****
				IF lnI > this.nMaxProcessesToSpawn
					* No room to spawn another yet
					RETURN 0
				ENDIF
			
			
			**********
			* Attempt to launch the process
			*****
				&lcArray[lnI, this._LAUNCHED_OK] = CreateProcess(tcExecutable, tcCmdLine, tcStartupDirectory, IIF(tlHideWindowOnLaunch, 0, 1))
				* Indicate success or failure based on return code
				RETURN &lcArray[lnI, this._LAUNCHED_OK]




	**********
	* Initial callback from the slave app to tell us its hwnd and id
	*	tnW = slave's hwnd
	*	tnL = slave id
	*****
		PROCEDURE slaveSaysHwnd
		LPARAMETERS tnHwnd, tnMsg, tnW, tnL
		LOCAL lnI, lcArray
			**********
			* Find the indicated slot for the process that's checking in
			*****
				lcArray = this.cMasterArrayName
				FOR lnI = 1 TO this.nMaxProcessesToSpawn
					IF &lcArray[lnI, this._USED] AND &lcArray[lnI, this._ID] = tnL
						* It is this entry
						&lcArray[lnI, this._REMOTE_HWND]		= tnW
						* Indicate success
						RETURN .t.
					ENDIF
				NEXT
				* Indicate failure
				RETURN .f.
	
	


	**********
	* Periodic callback to give this app a message about percent completed
	* They indicate a percent completed (tnW is integer portion, tnL is decimal portion)
	*****
		PROCEDURE slaveSaysPercentCompleted
		LPARAMETERS tnHwnd, tnMsg, tnW, tnL
		LOCAL lnI, lcArray
			**********
			* Find the indicated slot for the process that's checking in
			*****
				lcArray = this.cMasterArrayName
				FOR lnI = 1 TO this.nMaxProcessesToSpawn
					IF &lcArray[lnI, this._USED] AND &lcArray[lnI, this._ID] = tnW
						* It is this entry
						&lcArray[lnI, this._PERCENT] = tnL
						* Indicate success
						RETURN .t.
					ENDIF
				NEXT
				* Indicate failure
				RETURN .f.

	


	**********
	* Callback when the slave app is exiting
	*****
		PROCEDURE slaveSaysExiting
		LPARAMETERS tnHwnd, tnMsg, tnW, tnL
		LOCAL lnI, lcArray
			**********
			* They're exiting, find its slot and remove it from our master array's list of used entries
			*****
				lcArray = this.cMasterArrayName
				FOR lnI = 1 TO this.nMaxProcessesToSpawn
					IF &lcArray[lnI, this._USED] AND &lcArray[lnI, this._ID] = tnW
						* We can populate this entry
						&lcArray[lnI, this._USED]				= .f.
						&lcArray[lnI, this._TERMINATION_CODE]	= tnL
						* Indicate success
						RETURN .t.
					ENDIF
				NEXT
				* Indicate failure
				RETURN .f.




	**********
	* Bind the events
	*****
		PROCEDURE initializeSlave
		LPARAMETERS toForm
		LOCAL lnI, lcArray
			**********
			* Bind to the hwnd events we want to listen to
			*****
				BINDEVENT(toForm.hwnd, goMultiThread.nMessagePositionYourself,	goMultiThread, "masterSaysPositionYourself")
				BINDEVENT(toForm.hwnd, goMultiThread.nMessageSelfTerminate,		goMultiThread, "masterSaysSelfTerminate")




	**********
	* They are ready to shut down the slave
	*****
		PROCEDURE shutdownSlave
			* Unbind everything
			UNBINDEVENTS(0)

	


	**********
	* Callback from master to position the slave at coordinates
	*****
		PROCEDURE masterSaysPositionYourself
		LPARAMETERS tnHwnd, tnMsg, tnW, tnL
		LOCAL lnI, lcArray
			* The coordinate they give (tnW=X,tnL=Y) is the center of where they want the window positioned
			IF _screen.forms(1).left != tnW
				_screen.forms(1).left = tnW - (_screen.Forms(1).Width / 2)
			ENDIF
			IF _screen.forms(1).top != tnL
				_screen.forms(1).top = tnL - (_screen.Forms(1).Height / 2)
			ENDIF
			IF NOT _screen.Forms(1).visible
				_screen.Forms(1).visible = .t.
			ENDIF

	


	**********
	* Callback from master to have the slave self-terminate
	*****
		PROCEDURE masterSaysSelfTerminate
		LPARAMETERS tnHwnd, tnMsg, tnW, tnL
		LOCAL lnI, lcArray
			* Tell the master we're shutting down
			this.SendMessage(goCmdLine.hwnd, this.nMessageExiting, tnW, 0)
			* Shut down
			this.shutdownSlave
			_screen.forms(1).Release
			CLEAR EVENTS
		
ENDDEFINE




************************************************************************
* Note: The following code was taken from West Wind:
* http://www.west-wind.com/wconnect/weblog/ShowEntry.blog?id=533
************************************************************************
* wwAPI :: Createprocess
****************************************
*** Function: Calls the CreateProcess API to run a Windows application
*** Assume: Gets around RUN limitations which has command line
*** length limits and problems with long filenames.
*** Can do everything EXCEPT REDIRECTION TO FILE!
*** Pass: lcExe - Name of the Exe
*** lcCommandLine - Any command line arguments
*** Return: .t. or .f.
************************************************************************

FUNCTION Createprocess(lcExecutable, lcCommandLine, lcStartupDir, lnShowWindow)
LOCAL hProcess, cProcessInfo, cStartupInfo
 
DECLARE INTEGER CreateProcess IN kernel32 as _CreateProcess;
    STRING lpApplicationName,;
    STRING lpCommandLine,;
    INTEGER lpProcessAttributes,;
    INTEGER lpThreadAttributes,;
    INTEGER bInheritHandles,;
    INTEGER dwCreationFlags,;
    INTEGER lpEnvironment,;
    STRING lpCurrentDirectory,;
    STRING lpStartupInfo,;
    STRING @ lpProcessInformation

 
cProcessinfo = REPLICATE(CHR(0),128)
cStartupInfo = GetStartupInfo(lnShowWindow)
 
IF !EMPTY(lcCommandLine)
   lcCommandLine = ["] + lcExecutable + [" ]+ lcCommandLine
ELSE
   lcCommandLine = ""
ENDIF
 
lcExecutable	= FULLPATH(lcExecutable)
lcStartupDir	= FULLPATH(lcStartupDir)
lnResult = _CreateProcess(lcExecutable, lcCommandLine , 0, 0, 1, 0, 0, lcStartupDir, cStartupInfo, @cProcessInfo)
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

#DEFINE STARTF_USESTDHANDLES 0x0100
#DEFINE STARTF_USESHOWWINDOW 1
#DEFINE SW_HIDE 0
#DEFINE SW_SHOWMAXIMIZED 3
#DEFINE SW_SHOWNORMAL 1

lnFlags = STARTF_USESHOWWINDOW

RETURN binToChar(80) +;
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
*** Function: Binary Numeric conversion routine.
*** Converts DWORD or Unsigned Integer string
*** to Fox numeric integer value.
*** Pass: lcBinString - String that contains the binary data
*** llSigned - if .T. uses signed conversion
*** otherwise value is unsigned (DWORD)
*** Return: Fox number
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

* wwAPI :: CharToBin
***********************************************************************
FUNCTION BinToChar(lnValue)
****************************************
*** Function: Creates a DWORD value from a number
*** Pass: lnValue - VFP numeric integer (unsigned)
*** Return: binary string
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


* wwAPI :: BinToChar
************************************************************************
FUNCTION BinToWordChar(lnValue)
****************************************
*** Function: Creates a DWORD value from a number
*** Pass: lnValue - VFP numeric integer (unsigned)
*** Return: binary string
************************************************************************
RETURN Chr(MOD(m.lnValue,256)) + CHR(INT(m.lnValue/256))
