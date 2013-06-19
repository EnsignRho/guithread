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
//
// guithread.cpp:
//
//		guithread_create_interface					-- Returns hidden message hwnd used by the DLL
//		guithread_launch_remote_using_interface		-- Called to launch a new process that will communicate with this process
//		guithread_connect_as_remote_using_interface -- Called by the launched new process to setup the communication between the two
//		guithread_delete_interface					-- Used to shut down the interface if required (should be called when a process is terminated)
//		guithread_get_message						-- Called twice, once to find out how long the message is, the second time to actually retrieve the message
//		guithread_send_message						-- Called to send a message.  If cMessage is NULL, then a simple message is sent with only nValue and nExtra being used (nIdentifier is ignored, as is nMessageLength)
//		guithread_hwnd_on_taskbar					-- Used to show or hide a form's window on the taskbar (useful for creating background windows that do not "consume" taskbar space, but are used for conveying messages).
//
//////
	u32					guithread_create_interface					(u32 tnFormHwnd, u8* tcPipeName, u32 tlIsMaster);
	u32					guithread_launch_remote_using_interface		(u32 tnInterfaceId, u8* tcCommandLine);
	u32					guithread_connect_as_remote_using_interface	(u32 tnInterfaceId, u32 tnRemoteHwnd);
	u32					guithread_delete_interface					(u32 tnInterfaceId);
	u32					guithread_get_message						(u32 tnInterfaceId, u32 tnIdentifier, u8* tcMesageType100, u8* tcValue16, u8* tcExtra16, u8* tcMessage, u32 tnMessageLength);
	u32					guithread_send_message						(u32 tnInterfaceId, u32 tnValue, u32 tnExtra, u8* tcMessageType, u32 tnMessageTypeLength, u8* tcGeneralMessage, u32 tnGeneralMessageLength);
	u32					guithread_hwnd_on_taskbar					(u32 tnHwnd, u32 tnShow);


	// Internal functions
	SInterface*			iigt_FindSInterface							(SInterface** root, u32 tnInterfaceId);
	SInterface*			iigt_FindSInterfaceByRemoteMessageHwnd		(SInterface** root, u32 tnRemoteMessageHwnd);
	u32					iigt_getNextUniqueId						(void);
	void				iigt_copyString								(u8** tcDestination, u32* tnDestinationLength, u8* tcSource, u32 tnSourceLength, bool tlNullTerminate);
	u32					iigt_createMessageWindow					(SInterface* ti);
	SPipe*				iigt_connectPipe							(u8* tcPipeName, bool tlIsPipeOwner);
	u32					iigt_writeToPipe							(SInterface* ti, u8* tcData, u32 tnDataLength);
	u8*					iigt_readFromPipe							(SInterface* ti, u32 tnReadSize, u32* tnActuallyRead);
	SPipe*				iigt_createNewPipeStructure					(u8* tcPipeName);
	int					iigt_strlen									(u8* tcData);
	void				iigt_copyToShortestStringLength				(u8* tcDestination, u32 tnDestinationLength, u8* tcSource, u32 tnSourceLength, bool tlNullTerminate, bool tlPad, u8 tcPadChar);
	u32					iigt_stowMail								(SInterface* ti, u8* tcText, u32 tnTextLength, SParcel** tsMail);
	SParcel*			iigt_appendMail								(SParcel** mailbagRoot, u8* tcText, u32 tnTextLength, bool tlCopyString);
	SParcel*			iigt_findMail								(u32 tnMailId);
	void				iigt_findMailInInterface					(SInterface* ti, u32 tnMailId, SParcel** mail, SParcelDelivery** tpd);
	void				iigt_deleteMailParcel						(SInterface* ti, u32 tnMailId);
	SInterface*			iigt_createNewSInterface					(SInterface** root);
	void				iigt_createSPipe							(SPipe** pipe);
	u32					iigt_launchRemoteProcess					(SInterface* ti);
	bool				iigt_findLine								(u8* tcSource, u32 tnSourceLength, u8* tcLabelSearch, u32 tnLabelSearchLength, u8** tcLabelFound, u32* tnLabelFoundLength, u8** tcValueFound, u32* tnValueFoundLength);
	u32					iigt_get_u32								(u8* tcNumber, bool tlSkipLeadingWhitespaces);
	bool				iigt_isBetween								(s32 tnValue, s32 tnLow, s32 tnHigh);

	u32					iigt_sendParcelDeliveryViaPipe				(SInterface* ti, SParcelDelivery* tpd);
	u32					iigt_sendMessageViaPipe						(SInterface* ti, SParcelDelivery* tpd, u32 tnValue, u32 tnExtra, u8* tcMessageType, u32 tnMessageTypeLength, u8* tcGeneralMessage, u32 tnGeneralMessageLength);
	void				iigt_receiveAndProcessMessage				(SInterface* ti, u8* tcGeneralMessage, u32 tnGeneralMessageLength, u32 tnHwnd);
	SParcelDelivery*	iigt_createParcelDelivery					(u32 tnValue, u32 tnExtra, u8* tcMessageType, u32 tnMessageTypeLength, u8* tcGeneralMessage, u32 tnGeneralMessageLength);

	void				iigt_appendLabelColonValueString			(u8** tcData, u32* tnLength, u8* tcLabel, u32 tnLabelLength, u8* tcValue, u32 tnValueLength);
	void				iigt_appendLabelColonValueInteger			(u8** tcData, u32* tnLength, u8* tcLabel, u32 tnLabelLength, u32 tnValue);
	void				iigt_appendLabelColonValueFloat				(u8** tcData, u32* tnLength, u8* tcLabel, u32 tnLabelLength, f32 tfValue, u32 tnIntegers, u32 tnDecimals);
	void				iigt_prependLabelColonValueString			(u8** tcData, u32* tnLength, u8* tcLabel, u32 tnLabelLength, u8* tcValue, u32 tnValueLength);
	void				iigt_prependLabelColonValueInteger			(u8** tcData, u32* tnLength, u8* tcLabel, u32 tnLabelLength, u32 tnValue);
	void				iigt_prependLabelColonValueFloat			(u8** tcData, u32* tnLength, u8* tcLabel, u32 tnLabelLength, f32 tfValue, u32 tnIntegers, u32 tnDecimals);
	void				iigt_getLabelColonValueString				(u8* tcSource, u32 tnSourceLength, u8* tcLabel, u32 tnLabelLength, u8** tcText, u32** tnTextLength);
	void				iigt_getLabelColonValueInteger				(u8* tcSource, u32 tnSourceLength, u8* tcLabel, u32 tnLabelLength, u32** tnValue);
	void				iigt_getLabelColonValueFloat				(u8* tcSource, u32 tnSourceLength, u8* tcLabel, u32 tnLabelLength, f32** tfValue);


	// SHA-1 validation
	u32					iigt_computeSha1OnParcelDelivery			(SParcelDelivery* tpd);
	bool				iigt_validateParcelDeliverySha1s			(SParcelDelivery* tpd);
	bool				iigt_validateParcelDeliverylSha1_32_lftve_mt_c(SParcelDelivery* tpd);
	bool				iigt_validateParcelDeliverySha1_32_messageType(SParcelDelivery* tpd);
	bool				iigt_validateParcelDeliverySha1_32_content	(SParcelDelivery* tpd);
	bool				iigt_validateParcelDeliverySha1_32_all		(SParcelDelivery* tpd);
	u32					iigt_computeSha1_32							(u8* tcData, u32 tnDataLength);
	u8					iigt_swapBits								(u8 tcChar);
	u32					iigt_shiftLeft								(u32 tnValue, u32 tnBits);
	bool				iigt_equalEqual								(u8* tcLeft, u32 tnLeftLength, u8* tcRight, u32 tnRightLength);


	// WndProcs and thread functions
	DWORD WINAPI		igt_launchUsingInterfaceWorkerThread		(LPVOID lpThreadParameter);
	LRESULT CALLBACK	igt_interfaceWndProc						(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
