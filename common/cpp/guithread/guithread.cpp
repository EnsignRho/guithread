//////////
//
// guithread.cpp
//
//////
//
//




#include "stdafx.h"
#include "const.h"
#include "structs.h"
#include "globals.h"
#include "defs.h"




//////////
//
// Called to create an interface as either master or slave to/for the remote process.
// Returns hidden message hwnd used by the DLL
//
//////
	u32 guithread_create_interface(u32 tnFormHwnd, u8* cPipeName, u32 tlIsMaster)
	{
		// Indicate failure
		return(-1);
	}




//////////
//
// Called to delete a previously created interface.
// Used to shut down the interface if required (should be called when a process is terminated)
//
//////
	u32 guithread_delete_interface(u32 tnGuiThreadDllHwnd, u32 tnFormHwnd)
	{
		// Indicate failure
		return(-2);
	}




//////////
//
// Called to retrieve a message that's been notified is ready
// Called twice, once to find out how long the message is, the second time to actually retrieve the message
//
//////
	u32 guithread_get_message(u32 tnIdentifier, u8* tcMessage, u32 tnMessageLength)
	{
		// Indicate failure
		return(-3);
	}




//////////
//
// Called to send a message.
// If cMessage is NULL, then a simple message is sent with only nValue and nExtra being used (nIdentifier is ignored, as is nMessageLength)
//
//////
	u32 guithread_send_message(u32 tnFormHwnd, u32 tnIdentifier, u8* tcMessage, u32 tnMessageLength)
	{
		// Indicate failure
		return(-4);
	}
