**********
*
* handler.prg
*
*****
* November 07, 2012
* by Rick C. Hodgin
*****




**********
* Each app should create a single object:
*
* Initialization steps:
*		main.prg:
*				SET PROCEDURE TO handler.prg ADDITIVE
*		frmMain.Init():
*				PUBLIC goMultiThread
*				* To initialize as master:  goMultiThread = CREATEOBJECT("MultiThreadHandler", thisForm, .t.)
*				* To initialize as slave:   goMultiThread = CREATEOBJECT("MultiThreadHandler", thisForm)
*
**********
* Usage (the following use these parameters: tnValue, tnExtra, tcIdentifier, tcCommand):
*		mth_execute_remote_command					- Asks the remote to execute a command
*		mth_execute_remote_command_return_result	- Asks the remote to execute a command and then return the result
*		mth_send_general_message					- Sends the remote a general message
*		mth_send_response							- Send a response from a mth_execute_remote_command_return_result() call
*
* Usage (these parameters: tnHwnd, tnMsg, tnValue, tnExtra):
*		mth_send_message
*
* Usage (all the below use these parameters: tnValue, tnExtra, tcIdentifier, tcCommand):
*		on_execute_command							- When a message comes in from the remote to execute a command
*		on_execute_command_return_result			- When a message comes in from the remote to execute a command and return a result
*		on_general_message							- When a general message comes from the remote
*		on_response									- When a response to a previous mth_execute_command_return_result() was issued
*
**********
	



DEFINE CLASS MultiThreadHandler AS Session
	**********
	* This holds the location of the dll for this application
	*****
		dll_name								= "guithread.dll"
		slave_form_hwnd							= 0
		slave_dll_message_hwnd					= 0


	**********
	* Used by master only for the master array name
	*****
		cMasterArrayName						= SPACE(0)
		nMaxProcessesToSpawn					= 8
		nNextIdNumber							= 1
		nLastLaunchedIdNumber					= 0


	**********
	* These custom messages are referenced by both (can be any number 1024 or higher)
	* They are created here instead of constants so it's realized what they relate to.
	* Use as "goMultiThread.nMessageHwnd" for example
	*****
		nMessageHwnd							= 2000
		nMessagePercentCompleted				= 2001
		nMessageExiting							= 2002
		nMessagePositionYourself				= 2003
		nMessageSelfTerminate					= 2004
		nMessageByIdentifier					= 2005

	
	**********
	* Constants used to access cMasterArrayName array's columns
	*****
		_USED									= 1
		_ID										= 2
		_EXE_NAME								= 3
		_CMD_LINE								= 4
		_START_DIR								= 5
		_REMOTE_HWND							= 6
		_PERCENT								= 7
		_LAUNCHED_OK							= 8
		_LAUNCH_DATETIME						= 9
		_FORM_HWND								= 10
		_DLL_MESSAGE_HWND						= 11
		_DLL_MESSAGE_PIPE_NAME					= 12
		_TERMINATION_CODE						= 13
		_MAX_COLUMNS							= 13
	
	


	**********
	* Initialize the interface with the DLL
	*****
		PROCEDURE Init
		LPARAMETERS toForm, tlIsMaster
		
			**********
			* Initialize the DLL interface
			*****
				* Used one time in either launchSlaveProcess() or initializeSlave(), returns hidden message hwnd used by the DLL
				DECLARE INTEGER		guithread_create_interface ;
										IN (this.dll_name) ;
										INTEGER	nFormHwnd, ;			&& The form's HWND for notifications that data has been sent through the pipe
										STRING@	cPipeName, ;			&& Specify the pipe name
										INTEGER	nIsMaster				&& 0=Slave, 1=Master
				
				* Used to shut down the interface if required (should be called when a process is terminated)
				DECLARE INTEGER		guithread_delete_interface ;
										IN (this.dll_name) ;
										INTEGER	nGuiThreadDllHwnd, ;	&& The return value from the initial guithread_create_interface() function
										INTEGER	nFormHwnd ;				&& The form's HWND for notifications that data has been sent through the pipe
				
				* Called twice, once to find out how long the message is, the second time to actually retrieve the message
				DECLARE INTEGER		guithread_get_message ;
										IN (this.dll_name) ;
										INTEGER	nIdentifier, ;			&& The identifier conveyed for the message
										STRING@	cMessage, ;				&& Retrieve the message
										INTEGER	nMessageLength			&& Space reserved in cMessage to retrieve the content
				
				* Called once to send a message 
				DECLARE INTEGER		guithread_send_message ;
										IN (this.dll_name) ;
										INTEGER	nFormHwnd, ;			&& The hwnd to notify after the message is sent
										INTEGER	nIdentifier, ;			&& The identifier to convey for this message
										STRING@	cMessage, ;				&& Retrieve the message
										INTEGER	nMessageLength			&& Space reserved in cMessage to retrieve the content
			
			
			**********
			* Are we able to initialize our identity?
			*****
				IF TYPE("toForm") = "O" AND TYPE("toForm.class") = "C" AND LOWER(toForm.class) = "form" AND TYPE("tlIsMaster") = "L"
					* We have correct information
					IF tlIsMaster
						this.initializeMaster(toForm)
					ELSE
						this.initializeSlave(toForm)
					ENDIF
				ENDIF




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
					&lcArray[lnI, this._USED]					= .f.
					&lcArray[lnI, this._ID]						= 0
					&lcArray[lnI, this._EXE_NAME]				= SPACE(0)
					&lcArray[lnI, this._CMD_LINE]				= SPACE(0)
					&lcArray[lnI, this._START_DIR]				= SPACE(0)
					&lcArray[lnI, this._REMOTE_HWND]			= -1
					&lcArray[lnI, this._PERCENT]				= 0
					&lcArray[lnI, this._LAUNCHED_OK]			= .f.
					&lcArray[lnI, this._LAUNCH_DATETIME]		= CTOT("  /  /       :  :  ")
					&lcArray[lnI, this._FORM_HWND]				= 0
					&lcArray[lnI, this._DLL_MESSAGE_HWND]		= 0
					&lcArray[lnI, this._DLL_MESSAGE_PIPE_NAME]	= SPACE(0)
					&lcArray[lnI, this._TERMINATION_CODE]		= 0
				NEXT
		
			**********
			* Bind to the hwnd events we want to listen to
			*****
				BINDEVENT(toForm.hwnd, this.nMessageHwnd,							this, "slaveSaysHwnd")
				BINDEVENT(toForm.hwnd, this.nMessagePercentCompleted,				this, "slaveSaysPercentCompleted")
				BINDEVENT(toForm.hwnd, this.nMessageExiting,						this, "slaveSaysExiting")
				BINDEVENT(toForm.hwnd, this.nMessageByIdentifier,					this, "imth_raw_incoming_guithread_dll_message")




	**********
	* They are ready to shut down the master
	*****
		PROCEDURE shutdownMaster
		
			**********
			* Disconnect the dll message window
			*****
				guithread_delete_interface(this.slave_dll_message_hwnd, this.slave_form_hwnd)
		
		
			**********
			* Unbind everything
			*****
				UNBINDEVENTS(0)
				* We'll leave the array populated as the object will be destroy at some point soon




	**********
	* Launches a process quietly (without a command window)
	* Returns:
	*		(numeric)	- 0=indicates there are zero slots left in which to launch in (nMaxProcessesToSpawn is full of running processes)
	*		(numeric)	- -1=parameter error
	*		(numeric)	- -2=did not launch okay
	*		(numeric)	- 1 or above = slot it launched into
	*****
		PROCEDURE launchSlaveProcess
		LPARAMETERS toForm, tcPipeName, tcExecutable, tcCmdLine, tcStartupDirectory, tlHideWindowOnLaunch
		LOCAL lnI, lcArray
		
			**********
			* Only the tcExecutable parameter IS required
			*****
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
						&lcArray[lnI, this._USED]					= .t.
						&lcArray[lnI, this._ID]						= this.nNextIdNumber
						this.nLastLaunchedIdNumber					= this.nNextIdNumber
						&lcArray[lnI, this._EXE_NAME]				= tcExecutable
						&lcArray[lnI, this._CMD_LINE]				= tcCmdLine
						&lcArray[lnI, this._START_DIR]				= tcStartupDirectory
						&lcArray[lnI, this._REMOTE_HWND]			= -1
						&lcArray[lnI, this._PERCENT]				= 0
						&lcArray[lnI, this._LAUNCHED_OK]			= .f.			&& Will be set to true conditoin below
						&lcArray[lnI, this._LAUNCH_DATETIME]		= DATETIME()
						&lcArray[lnI, this._FORM_HWND]				= toForm.hwnd
						&lcArray[lnI, this._DLL_MESSAGE_HWND]		= guithread_create_interface(toForm, tcPipeName, 1)
						&lcArray[lnI, this._DLL_MESSAGE_PIPE_NAME]	= tcPipeName
						&lcArray[lnI, this._TERMINATION_CODE]		= 0
						
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
				tcCmdLine = tcCmdLine + " -pipe:" + tcPipeName
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
					
						**********
						* This was the ntry that was used
						*****
							&lcArray[lnI, this._USED]				= .f.
							&lcArray[lnI, this._TERMINATION_CODE]	= tnL
		
						**********
						* Disconnect the dll message window
						*****
							guithread_delete_interface(&lcArray[lnI, this._DLL_MESSAGE_HWND], &lcArray[lnI, this._FORM_HWND])
						
						* Indicate success
						RETURN .t.
					ENDIF
				NEXT
				* Indicate failure
				RETURN .f.




	**********
	* Callback when the slave wants us to execute a command
	*****
		PROCEDURE slaveSaysExecuteCommand
		LPARAMETERS tnHwnd, tnMsg, tnIdentifier, tnL




	**********
	* Callback when the slave wants us to execute a command and explicitly return the command
	*****
		PROCEDURE slaveSaysExecuteCommandReturnResult
		LPARAMETERS tnHwnd, tnMsg, tnIdentifier, tnL




	**********
	* Callback when the slave has sent us a general message
	*****
		PROCEDURE slaveSentGeneralMessage
		LPARAMETERS tnHwnd, tnMsg, tnIdentifier, tnL




	**********
	* Callback when the slave has sent us a response to a prior request to execute a command and return the result
	*****
		PROCEDURE slaveSentResponse
		LPARAMETERS tnHwnd, tnMsg, tnIdentifier, tnL




	**********
	* Bind the events
	*****
		PROCEDURE initializeSlave
		LPARAMETERS toForm, tcPipeName
		LOCAL lnI, lcArray
		
			**********
			* Create our connection to the remote
			*****
				this.slave_form_hwnd		= toForm.hwnd
				this.slave_dll_message_hwnd = guithread_create_interface(toForm, tcPipeName, 0)
		
		
			**********
			* Bind to the hwnd events we want to listen to
			*****
				BINDEVENT(toForm.hwnd, this.nMessagePositionYourself,				this, "masterSaysPositionYourself")
				BINDEVENT(toForm.hwnd, this.nMessageSelfTerminate,					this, "masterSaysSelfTerminate")
				BINDEVENT(toForm.hwnd, this.nMessageByIdentifier,					this, "imth_raw_incoming_guithread_dll_message")




	**********
	* They are ready to shut down the slave
	*****
		PROCEDURE shutdownSlave
		
			**********
			* Disconnect the dll message window
			*****
				guithread_delete_interface(this.slave_dll_message_hwnd, this.slave_form_hwnd)


			**********
			* Unbind everything
			*****
				UNBINDEVENTS(0)

	


	**********
	* Callback from master to position the slave at coordinates
	*****
		PROCEDURE masterSaysPositionYourself
		LPARAMETERS tnHwnd, tnMsg, tnW, tnL
		LOCAL lnI, lcArray
		
			**********
			* The coordinate they give (tnW=X,tnL=Y) is the center of where they want the window positioned
			*****
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
		
			**********
			* Tell the master we're shutting down
			*****
				this.imth_send_message(this.slave_dll_message_hwnd, this.nMessageExiting, tnW, tnL)
		
		
			**********
			* Shut down
			*****
				this.shutdownSlave
				_screen.forms(1).Release
				CLEAR EVENTS




	**********
	* Internal common method for sending messages from here (the local) to there (the remote) through the guithreaddll
	*****
		HIDDEN PROCEDURE imth_send_guithread_message
		LPARAMETERS tcOperation, tnValue, tnExtra, tcIdentifier, tcCommand, tnSlotOfMaster
		LOCAL lnI, lcArray, lnFormHwnd, lnSlaveDllMessageHwnd, lcMessage
		
			**********
			* Prepare the message to transmit through guithread.dll
			*****
				lcMessage		= tcOperation
				lcMessage		= lcMessage + tcIdentifier + CHR(13)
				lcMessage		= lcMessage + TRANSFORM(tnValue) + CHR(13)
				lcMessage		= lcMessage + TRANSFORM(tnExtra) + CHR(13)
				lcMessage		= lcMessage + tcCommand


			**********
			* Make sure the slot is indicated, or we're sending as a slave
			*****
				* Is it the slave?
				IF TYPE("tnSlotOfMaster") = "L"
					* It's the slave
					lnFormHwnd				= this.slave_form_hwnd
					lnSlaveDllMessageHwnd	= this.slave_dll_message_hwnd
				ENDIF
				
				* Is it the master?
				IF TYPE("tnSlotOfMaster") = "N" AND tnSlotOfMaster <= this.nMaxProcessesToSpawn
					* It's the master, locate the slot
					lcArray					= this.cMasterArrayName
					lnFormHwnd				= &lcArray[tnSlotOfMaster, this._FORM_HWND]
					lnSlaveDllMessageHwnd	= &lcArray[tnSlotOfMaster, this._DLL_MESSAGE_HWND]
				
				ELSE
					* Nope.  It's an improper thing that's happening here.
					* It makes us sad, but we can deal with it.
					RETURN .f.
				ENDIF
			
			
			**********
			* Send it
			*****
				guithread_send_message(lnFormHwnd, lnSlaveDllMessageHwnd, tcMessage, LEN(tcMessage))
				RETURN .t.




	**********
	* Callback from the guithread.dll when a message has been sent and is ready
	*****
		HIDDEN PROCEDURE imth_raw_incoming_guithread_dll_message
		LPARAMETERS tnHwnd, tnMsg, tnIdentifier, tnL
		LOCAL lnLength, lcMessage, laLines, lnValue, lnExtra, lcOperation, lcCommand, lcIdentifier
		
			**********
			* Retrieve the message
			*****
				lnLength = guithread_get_message(tnIdentifier, NULL, 0)
				IF lnLength > 0
					lcMessage = SPACE(lnLength)
					guithread_get_message(tnIdentifier, @lcMessage, LEN(lcMessage))
				
				
					**********
					* Parse the message text
					*****
						DIMENSION laLines[1]
						ALINES(laLines, lcMessage)
						
						* Is it a valid message?
						IF NOT EMPTY(laLines) AND ALEN(laLines, 1) >= 5
						
							**********
							* Grab the operation and numeric portions
							*****
								lcOperation		= laLines[1]
								lcIdentifier	= laLines[2]
								lnValue			= VAL(laLines[3])
								lnExtra			= VAL(laLines[4])
							
							
							**********
							* Grab the actual command
							*****
								lcCommand = SPACE(0)
								FOR lnI = 5 TO ALEN(laLines, 1)
									lcCommand = laLines[lnI] + IIF(lnI < ALEN(laLines, 1), CHR(13), SPACE(0))
								NEXT
							
							
							**********
							* Spawn the appropriate event
							*****
								DO CASE
									CASE lcOperation = "execute_command"
										this.on_execute_command(lnValue, lnExtra, lcIdentifier, lcCommand)
								
									CASE lcOperation = "execute_command_return_result"
										this.on_execute_command_return_result(lnValue, lnExtra, lcIdentifier, lcCommand)
								
									CASE lcOperation = "general_message"
										this.on_execute_command(lnValue, lnExtra, lcIdentifier, lcCommand)
								
									CASE lcOperation = "response"
										this.on_response(lnValue, lnExtra, lcIdentifier, lcCommand)
								
								ENDCASE
						ENDIF
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
			LPARAMETERS tnValue, tnExtra, tcIdentifier, tcCommand
		
		
		**********
		* The remote wants us to execute a command, and then return the result using the identifier
		*****
			PROCEDURE on_execute_command_return_result
			LPARAMETERS tnValue, tnExtra, tcIdentifier, tcCommand
		
		
		**********
		* The remote has sent us a general message
		*****
			PROCEDURE on_general_message
			LPARAMETERS tnValue, tnExtra, tcIdentifier, tcMessage
		
		
		**********
		* The remote has sent us a response to a prior comand
		*****
			PROCEDURE on_response
			LPARAMETERS tnValue, tnExtra, tcIdentifier, tcResponse
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
			LPARAMETERS tnValue, tnExtra, tcIdentifier, tcCommand, tnSlotOfMaster
				imth_send_guithread_message("execute_command", tnValue, tnExtra, tcIdentifier, tcCommand, tnSlotOfMaster)
		
		
		**********
		* We want the remote to execute a command, and return us a result
		*****
			PROCEDURE mth_execute_remote_command_return_result
			LPARAMETERS tnValue, tnExtra, tcIdentifier, tcCommand
				imth_send_guithread_message("execute_command_return_result", tnValue, tnExtra, tcIdentifier, tcCommand, tnSlotOfMaster)
		
		
		**********
		* We want to send the remote a general message
		*****
			PROCEDURE mth_send_general_message
			LPARAMETERS tnValue, tnExtra, tcIdentifier, tcCommand
				imth_send_guithread_message("general_message", tnValue, tnExtra, tcIdentifier, tcCommand, tnSlotOfMaster)
		
		
		**********
		* We want to send the remote a response
		*****
			PROCEDURE mth_send_response
			LPARAMETERS tnValue, tnExtra, tcIdentifier, tcCommand
				imth_send_guithread_message("response", tnValue, tnExtra, tcIdentifier, tcCommand, tnSlotOfMaster)
	
	
		**********
		* Send a message to a remote hwnd
		*****
			PROCEDURE mth_send_message
			LPARAMETERS tnHwnd, tnMsg, tnValue, tnExtra
			LOCAL lnResult
				DECLARE INTEGER SendMessage IN WIN32API AS SendMessageMultiThread INTEGER hwnd, INTEGER msg, INTEGER w, INTEGER l
				lnResult = SendMessageMultiThread(tnHwnd, tnMsg, tnValue, tnExtra)
				CLEAR DLLS SendMessageMultiThread
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
