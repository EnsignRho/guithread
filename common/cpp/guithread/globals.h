//////////
//
// globals.h
//
//////
//
// by Rick C. Hodgin
// June 13, 2013
//
//////
//
// Global variable definitions
//
//////









//////////
// guithread.cpp
//////
#ifndef _isExtern
#define _isExtern
#endif
#ifndef _initialize
#define _initialize(...) = __VA_ARGS__
#endif
	_isExtern	u32					gnNextUniqueId					_initialize(0);						// Used internally
	_isExtern	CRITICAL_SECTION	gsemUniqueIdAccess;
	_isExtern	SInterface*			gsInterfaces					_initialize(NULL);					// Root list of interfaces
	_isExtern	SInterface*			gsInterfaceSelf					_initialize(NULL);					// Used for self items
	_isExtern	ATOM				gnAtom							_initialize(NULL);					// Is the message window class registered?
