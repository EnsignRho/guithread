//////////
//
// defs.h
//
//////
//
// by Rick C. Hodgin
// June 13, 2013
//
//////
//
// Prototype function definitions
//
//////









//////////
// guithread.cpp
//////
	// Returns hidden message hwnd used by the DLL
	u32		guithread_create_interface						(u32 tnFormHwnd, u8* cPipeName, u32 tlIsMaster);

	// Used to shut down the interface if required (should be called when a process is terminated)
	u32		guithread_delete_interface						(u32 tnGuiThreadDllHwnd, u32 tnFormHwnd);

	// Called twice, once to find out how long the message is, the second time to actually retrieve the message
	u32		guithread_get_message							(u32 tnIdentifier, u8* tcMessage, u32 tnMessageLength);
	
	// Called to send a message.  If cMessage is NULL, then a simple message is sent with only nValue and nExtra being used (nIdentifier is ignored, as is nMessageLength)
	u32		guithread_send_message							(u32 tnFormHwnd, u32 tnIdentifier, u8* tcMessage, u32 tnMessageLength);
