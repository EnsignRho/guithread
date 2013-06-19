**********
*
* handler.prg
*
*****
* June 13, 2013
* by Rick C. Hodgin
*****









**********
*
* Initialization steps.
*
*		**********
*		* Note:  It is recommended to subclass GuiThreadHandler and
*		*        create custom methods for the mth() and on() functions.
*		**********
*
* Each app should create a single object:
*
*		main.prg:
*				SET PROCEDURE TO handler.prg ADDITIVE
*
*
*		frmMain.Init():
*				PUBLIC goGuiThread
*				goGuiThread = CREATEOBJECT("GuiThreadHandler", thisForm, llIsMaster)
*
***********
* Usage by both Master and Slave:
*
*	Methods:
*		mth_execute_remote_command()					-- Called to execute a command remotely
*		mth_execute_remote_command_return_result()		-- Called to execute a command remotely, and return a result
*		mth_send_general_message()						-- Called to send a general text message, and two integers, to the remote
*		mth_send_result()								-- Called to send a result back to the remote
*		mth_send_simple_message()						-- Called to send a simple message of two integers to the remote
*
*	Events:
*		on_execute_command()							-- When the remote has a command for us to execute, it is sent here
*		on_execute_command_return_result()				-- When the remote has a command for us to execute, and it expects a result to be sent back, it is sent here
*		on_general_message()							-- When the remote has sent us a general message with a text message and two integers, it is sent here
*		on_result()										-- When the remote has sent us a result, it is sent here
*		on_simple_message()								-- When the remote has sent us a simple message with two integers, it is sent here
*
**********
	



DEFINE CLASS GuiThreadHandler AS Session

	#define WM_USER					0x0400
	#define WMGT_PARCEL_DELIVERY	WM_USER + 100


	**********
	* This holds the location of the dll for this application
	*****
		dll_name = "guithread.dll"		&& Name of the dll, can be renamed anything
	


	**********
	* Initialize the interface with the DLL
	*****
		PROCEDURE Init
		LPARAMETERS toForm, tlIsMaster
		
			**********
			* Initialize the DLL interface.
			* The DLL interfaces with its remote counterpart, creating some essential behind-the-scenes
			* mechanisms to carry out the mechanics of fulfilling the requests exposed below by this API.
			*****
				* Used one time in either launchSlaveProcess() or initializeSlave()
				* Returns the nInterfaceId used by the DLL
				DECLARE INTEGER		guithread_create_interface ;
										IN (this.dll_name) ;
										INTEGER	nFormHwnd, ;			&& The form's HWND for notifications that data has been sent through the pipe
										STRING	cPipeName, ;			&& Specify a unique name for the data pipe
										INTEGER	nIsMaster				&& 0=Slave, 1=Master

				* Launches an application and uses the specified nInterfaceId
				DECLARE INTEGER		guithread_launch_remote_using_interface ;
										IN (this.dll_name) ;
										INTEGER	nInterfaceId, ;			&& The return value from the initial guithread_create_interface() function
										STRING	cCommandLine			&& "c:\path\to\myapp.exe myparam1 myparam2"

				* Used in the remote launched app to establish a connection back to the original local (the "remote" from its point of view)
				DECLARE INTEGER		guithread_connect_as_remote_using_interface	;
										IN (this.dll_name) ;
										INTEGER	nInterfaceId, ;			&& The return value from the initial guithread_create_interface() function
										INTEGER	tnRemoteHwnd			&& Specify the remote hwnd 

				* Used to shut down the interface if required (should be called when a process is terminated)
				* Returns -1 if the identified hwnds are unknown, 0 otherwise.
				DECLARE INTEGER		guithread_delete_interface ;
										IN (this.dll_name) ;
										INTEGER	nInterfaceId			&& The return value from the initial guithread_create_interface() function
				
				* Called twice, once to find out how long the message is, the second time to actually retrieve the message
				* Returns the length of bytes to copy if nMessageLength = 0, or the number of bytes copied if nMessageLength > 0.
				* The message is auto-deleted once all bytes are read.
				* Subsequent calls to a partially read message retrieves the entire message.
				DECLARE INTEGER		guithread_get_message ;
										IN (this.dll_name) ;
										INTEGER	nInterfaceId, ;			&& The return value from the initial guithread_create_interface() function
										INTEGER	nIdentifier, ;			&& The message's unique identifier
										STRING@	cMessageType100, ;		&& A 100 character buffer to receive the message type
										STRING@	cMessage, ;				&& Retrieve the message
										INTEGER	nMessageLength			&& Space reserved in cMessage to retrieve the content
				
				* Called to send a message.  If cMessage is NULL, then a simple message is sent with only nValue and nExtra
				* being used (nIdentifier is ignored, as is nMessageLength).
				DECLARE INTEGER		guithread_send_message ;
										IN (this.dll_name) ;
										INTEGER	nInterfaceId, ;			&& The return value from the initial guithread_create_interface() function
										INTEGER	nValue, ;				&& A numeric value to send
										INTEGER	nExtra, ;				&& An extra numeric value to send
										STRING	cMessageType, ;			&& A type of message being sent (user-defined)
										INTEGER	nMessageTypeLength, ;	&& Length of the message type being sent
										STRING	cGeneralMessage, ;		&& What message to send
										INTEGER	nGeneralMessageLength	&& How long is the message we're sending?
				
				* Used to show or hide a form's window on the taskbar (useful for creating
				* background windows that do not "consume" taskbar space, but are used for
				* conveying messages).
				DECLARE INTEGER		guithread_hwnd_on_taskbar ;
										IN (this.dll_name) ;
										INTEGER	nHwnd, ;				&& The thisForm.hwnd to hide from the taskbar
										INTEGER	nShow					&& 0=hide, !0=show
			
			
			**********
			* Are we able to initialize our identity?
			*****
				IF TYPE("toForm") = "O" AND TYPE("toForm.class") = "C" AND LOWER(toForm.class) = "form" AND TYPE("tlIsMaster") = "L"
					* We have correct information
					IF tlIsMaster
						this.initializeMaster(toForm)		&& We are the master
					ELSE
						this.initializeSlave(toForm)		&& We are the slave
					ENDIF
				*ELSE
				* It can be initialized later if need be by manually calling Init()
				ENDIF


			**********
			* Bind to the hwnd events we want to listen to
			*****
				BINDEVENT(toForm.hwnd, WMGT_PARCEL_DELIVERY, this, "imth_raw_incoming_guithread_dll_message")




	**********
	* They are ready to shut down
	*****
		PROCEDURE Unload
			**********
			* Unbind everything
			*****
				UNBINDEVENTS(0)
				* We'll leave the array populated as the object will be destroy at some point soon




	**********
	* Launches a process quietly (without a command window)
	* Returns the interfaceId to use for future calls to/from this process
	*****
		PROCEDURE launchRemoteProcess
		LPARAMETERS toForm, tcPipeName, tcCommandLine
		LOCAL lnInterfaceId
			**********
			* Make sure the command line is setup properly.
			*
			* Note:  The guithread_launch_remote_using_interface will automatically append two parameters:
			*            -hwnd:1234567890
			*            -pipe:pipeName
			*****
				IF TYPE("tcCommandLine") != "C"
					RETURN -1
				ENDIF
			
			**********
			* Attempt to launch the process
			*****
				lnInterfaceId = guithread_create_interface(toForm.hwnd, tcPipeName, 1)
				IF lnInterfaceId >= 0
					* Launches an application and uses the specified nInterfaceId
					RETURN guithread_launch_remote_using_interface(lnInterfaceId, tcCommandLine)
				ENDIF




	**********
	* Callback from the guithread.dll when a message has been sent and is ready
	*****
		HIDDEN PROCEDURE imth_raw_incoming_guithread_dll_message
		LPARAMETERS tnHwnd, tnMsg, tnIdentifier, tnL
		LOCAL lnLength, lcMessageType100, lcMessage, lcValue16, lcExtra16
		
			**********
			* Retrieve the message
			*****
				lcMessageType100	= SPACE(100)
				lcValue16			= SPACE(16)
				lcExtra16			= SPACE(16)
				lnLength			= guithread_get_message(tnIdentifier, @lcMessageType100, @lcValue16, @lcExtra16, NULL, 0)
				IF lnLength > 0
					lcMessage = SPACE(lnLength)
					guithread_get_message(tnIdentifier, @lcMessageType100, @lcValue16, @lcExtra16, @lcMessage, LEN(lcMessage))
					
					
					**********
					* Spawn the appropriate event
					*****
						DO CASE
							CASE LOWER(lcMessageType) = "upandrunning"
								* Signal the event
* Working here:
**********
* Send it
*****
	guithread_send_message(tnInterfaceId, tnValue, tnExtra, tcMessageType, LEN(tcMesageType), tcCommand, LEN(tcCommand))

						ENDCASE
				ENDIF




********************
*
* E V E N T S
*
*********
		*
		*
		**********
		* The remote wants us to execute a command
		*****
			PROCEDURE on_execute_command
			LPARAMETERS tnRemoteId, tnValue, tnExtra, tcIdentifier, tcCommand
		
		
		**********
		* The remote wants us to execute a command, and then return the result using the identifier
		*****
			PROCEDURE on_execute_command_return_result
			LPARAMETERS tnRemoteId, tnValue, tnExtra, tcIdentifier, tcCommand
		
		
		**********
		* The remote has sent us a general message
		*****
			PROCEDURE on_general_message
			LPARAMETERS tnRemoteId, tnValue, tnExtra, tcIdentifier, tcMessage
		
		
		**********
		* The remote has sent us a result from a prior comand which needed to return a result
		*****
			PROCEDURE on_result
			LPARAMETERS tnRemoteId, tnValue, tnExtra, tcIdentifier, tcResponse
		
		
		**********
		* The remote has sent us a simple message
		*****
			PROCEDURE on_simple_message
			LPARAMETERS tnRemoteId, tnValue, tnExtra, tcIdentifier
		*
		*
*********
*
* E V E N T S
*
********************




********************
*
* M E T H O D S
*
*********
		*
		*
		**********
		* We want the remote to execute a command
		*****
			PROCEDURE mth_execute_remote_command
			LPARAMETERS tnRemoteId, tnValue, tnExtra, tcIdentifier, tcCommand
				imth_send_guithread_message(tnRemoteId, "execute_command", tnValue, tnExtra, tcIdentifier, tcCommand)
		
		
		**********
		* We want the remote to execute a command, and return us a result
		*****
			PROCEDURE mth_execute_remote_command_return_result
			LPARAMETERS tnRemoteId, tnValue, tnExtra, tcIdentifier, tcCommand
				imth_send_guithread_message(tnRemoteId, "execute_command_return_result", tnValue, tnExtra, tcIdentifier, tcCommand)
		
		
		**********
		* We want to send the remote a general message
		*****
			PROCEDURE mth_send_general_message
			LPARAMETERS tnRemoteId, tnValue, tnExtra, tcIdentifier, tcCommand
				imth_send_guithread_message(tnRemoteId, "general_message", tnValue, tnExtra, tcIdentifier, tcCommand)
		
		
		**********
		* We want to send the remote a result response
		*****
			PROCEDURE mth_send_result
			LPARAMETERS tnRemoteId, tnValue, tnExtra, tcIdentifier, tcCommand
				imth_send_guithread_message(tnRemoteId, "response", tnValue, tnExtra, tcIdentifier, tcCommand)
	
	
		**********
		* Send a simple message to a remote hwnd
		*****
			PROCEDURE mth_send_simple_message
			LPARAMETERS tnRemoteId, tnHwnd, tnMsg, tnValue, tnExtra
				imth_send_guithread_message(tnRemoteId, "simple_message", tnValue, tnExtra, tcIdentifier)
		*
		*
*********
*
* M E T H O D S
*
********************
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
