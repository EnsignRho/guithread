//////////
//
// structs.h
//
//////
//
// by Rick C. Hodgin
// June 13, 2013
//
//////
//
// Structure definitions
//
//////









//////////
// For supporting interfaces
//////


	//////////
	// The ParcelDelivery structure is used to send the parcel (message) through the pipe
	//////////
		struct SParcelDelivery
		{
		//////////
		//
		// All in hexadecimal (the pipe signs are for visual delineation):
		// 00000000|00000000|00000000|00000000|00000000|00000000|00000000.00000000|00000000.00000000|messageType|content
		// 
		// 00000000:Length
		// 00000000:SHA1-32 of Length, From, To, and the 00000000.00000000 portions of message type and content
		// 00000000:From
		// 00000000:To
		// 00000000:Value
		// 00000000:Extra Value
		// 00000000.00000000:Length of message type, SHA1-32 of message type text
		// 00000000.00000000:Length of content, SHA1-32 of content
		// 00000000:SHA1-32 of entire message from 00000000 in Length to last byte of content
		//
		//////
			u32			totalMessageLength;							// 00000000:Length
			u32			sha1_32_lftve_mt_c;							// 00000000:SHA1-32 of Length, From, To, and the 00000000.00000000 portions of message type and content
			u32			fromId;										// 00000000:From
			u32			toId;										// 00000000:To
			u32			nValue;										// 00000000:Value
			u32			nExtra;										// 00000000:Extra value
			u32			messageTypeLength;							// 00000000.00000000:Length of message type, SHA1-32 of message type text
			u32			messageTypeSha1_32;							// 
			u32			contentLength;								// 00000000.00000000:Length of content, SHA1-32 of content
			u32			contentLengthSha1_32;						// 
			u32			sha1_32_all;								// 00000000:SHA1-32 of entire message from 00000000 in totalMessageLength to last byte of content

			// These are appended based on their messageTypeLength and contentLength components immediately after the above in the message transferred through the named pipe
			u8*			messageType;								// The actual message type text, such as "mail", "mail encrypted", "general message", etc.
			u8*			content;									// The actual content, which is entirely dependent upon what the message type is
		};


	//////////
	// Internally, parcels (messages) are stored thusly
	//////
		struct SParcel
		{
			SParcel*	next;										// Pointer to next mailbag entry in the chain
			u32			mailId;										// Unique mail id number

			// Stored data for this entry
			u8*			data;										// Pointer to start of data
			u32			dataLength;									// Length of the data there
		};


	//////////
	// Data pipes are used to communicate between separate processes
	//////
		struct SPipe
		{
			int				error;										// If the handleRead failed to open, the error flag is raised, otherwise 0
			u32				handleRead;									// Pipe read handle after being created
			u32				handleWrite;								// Pipe write handle after being created
			u8*				name;										// Name of the pipe in use
			u32				nameLength;									// Length of the pipe name as allocated
			bool			isOwner;									// Is this the pipe owner?

			// Information needed by windows to create/connect to the pipe
			SECURITY_ATTRIBUTES sa;										// Security attributes used to create the pipe
		};


	//////////
	// The startup process requires certain parameters
	//////
		struct SParams
		{
			STARTUPINFOA		si;										// Startup info for the launched process
			PROCESS_INFORMATION	pi;										// Process information for the launched process
		};


	//////////
	// This DLL keeps track of everything it's communicating with remotely using this structure
	//////
		struct SInterface
		{
			SInterface*		next;										// 1-way link list
			u32				interfaceId;								// The unique ID for this interface
			bool			isRunning;									// Set when remote app is launched and has checked in

			// For launching the remote process
			SParams			params;										// Holds required startup parameters
			u32				procId;										// Remote process id

			// Bound hwnds
			u32				hwndBound;									// The Visual FoxPro form's HWND we use for callbacks
			u32				hwndLocalMessage;							// Our internal message window
			u32				hwndRemoteMessage;							// The remote internal message window we are communicating with

			// For reading/writing from/to remote process
			SPipe*			pipe;										// A two-way data pipe for communicating with the remote process
			u8*				pipeName;									// Name of the pipe this process uses
			u32				pipeNameLength;								// How long is the pipe name?

			// Incoming mail
			SParcel*		mailbag;									// Incoming mail for this process

			// That which created the interface
			u8*				commandLine;								// Provided for when an application is launched using this interface

			// Critical sections for atomic access during crucial operations
			CRITICAL_SECTION	cs_mailbag;							// Used for low-level mail operations
			CRITICAL_SECTION	cs_pipe;							// Used for low-level pipe operations
			CRITICAL_SECTION	cs_generalMessage;					// Used for general messages

			// Create the worker thread
			HANDLE			threadHandle;								// The worker thread handle
			DWORD			threadId;									// The worker thread id
		};
