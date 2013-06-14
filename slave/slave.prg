**********
*
* slave.prg
*
*****
* November 7, 2012
* by Rick C. Hodgin
*****
* Receive the command line parameters, as sent from the master
PARAMETERS tcHwndId, tcId, tcCommand, tcP1, tcP2, tcP3, tcP4, tcP5, tcP6, tcP7, tcP8, tcP9, tcP10


**********
* Set the basic stuff
*****
	SET STATUS OFF
	SET BELL OFF
	SET DOHISTORY OFF
	SET TALK OFF
	SET ENGINEBEHAVIOR 70
	SET STATUS BAR ON
	SET SAFETY OFF


**********
* Create the command line object we'll use globally
*****
	PUBLIC goCmdLine
	goCmdLine = CREATEOBJECT("Custom")
	goCmdLine.AddProperty("hwnd",	VAL(tcHwndId))
	goCmdLine.AddProperty("id",		VAL(tcId))
	goCmdLine.AddProperty("cmd",	IIF(TYPE("tcCommand")	= "C", tcCommand,	SPACE(1)))
	goCmdLine.AddProperty("p1",		IIF(TYPE("tcP1")		= "C", tcP1,		SPACE(1)))
	goCmdLine.AddProperty("p2",		IIF(TYPE("tcP2")		= "C", tcP1,		SPACE(1)))
	goCmdLine.AddProperty("p3",		IIF(TYPE("tcP3")		= "C", tcP1,		SPACE(1)))
	goCmdLine.AddProperty("p4",		IIF(TYPE("tcP4")		= "C", tcP1,		SPACE(1)))
	goCmdLine.AddProperty("p5",		IIF(TYPE("tcP5")		= "C", tcP1,		SPACE(1)))
	goCmdLine.AddProperty("p6",		IIF(TYPE("tcP6")		= "C", tcP1,		SPACE(1)))
	goCmdLine.AddProperty("p7",		IIF(TYPE("tcP7")		= "C", tcP1,		SPACE(1)))
	goCmdLine.AddProperty("p8",		IIF(TYPE("tcP8")		= "C", tcP1,		SPACE(1)))
	goCmdLine.AddProperty("p9",		IIF(TYPE("tcP9")		= "C", tcP1,		SPACE(1)))
	goCmdLine.AddProperty("p10",	IIF(TYPE("tcP10")		= "C", tcP1,		SPACE(1)))



**********
* We reference objects on the thread handler
*****
	SET PROCEDURE TO handler.prg ADDITIVE
	PUBLIC goGuiThread
	goGuiThread = NEWOBJECT("GuiThreadHandler")	
	

**********
* Load global variables
*****
	PUBLIC gcStartupDirectory
	gcStartupDirectory = FULLPATH(CURDIR())


**********
* Display the form.
* For the slave example, we use the tcCommand parameter
* to determine what to do.  See frmSlave.init().
*****
	_vfp.Visible = .f.
	DO FORM frmSlave


*********
* Wait until we're done
*****
	READ EVENTS


**********
* Upon termination, restore things
*****
	IF "\vfp9.exe" $ FULLPATH(LOWER(_vfp.ServerName))
		_vfp.Visible = .t.
	ENDIF
	SET TALK ON
	QUIT
