**********
*
* master.prg
*
*****
* June 13, 2013
* by Rick C. Hodgin
*****


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
* Create the base handler object
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
* Display the master form
*****
	_vfp.Visible = .f.
	DO FORM frmMaster


*********
* Wait until we're done
*****
	READ EVENTS


**********
* Upon termination, restore things
*****
	_vfp.Visible = .t.
	SET TALK ON
	CANCEL
