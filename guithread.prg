**********
*
* guithread.prg
*
*****
* Version 0.10
* Copyright (c) 2012 by Rick C. Hodgin
*****
* Last update:
*     November 06, 2012
*****
* Change log:
*     November 06, 2012 - Initial creation
*****
*
* This software is released as Liberty Software under a Repeat License,
* as governed by the Public Benefit License v1.0 or later (PBL).
*
* You are free to use, copy, modify and share this software.  However,
* it can only be released under the PBL version indicated, and every
* project must include a copy of the pbl.txt document for its version
* as is at http://www.libsf.org/licenses/.
*
* For additional information about this project, or to view the license,
* see:
*
*     http://www.libsf.org/
*     http://www.libsf.org/licenses/
*     http://www.visual-freepro.org
*     http://www.visual-freepro.org/blog/
*     http://www.visual-freepro.org/forum/
*     http://www.visual-freepro.org/wiki/
*     http://www.visual-freepro.org/wiki/index.php/PBL
*     http://www.visual-freepro.org/wiki/index.php/Repeat_License
*
* Thank you.  And may The Lord bless you richly as you lift up your life,
* your talents, your gifts, your praise, unto Him.  In Jesus' name I pray.
* Amen.
*
*****
PARAMETERS tcHwndId, tcCommand, tcP1, tcP2, tcP3, tcP4, tcP5, tcP6, tcP7, tcP8, tcP9, tcP10
* Create the command line object
PUBLIC goCmdLine
goCmdLine = CREATEOBJECT("Custom")
goCmdLine.AddProperty("hwnd",		VAL(tcHwndId))
goCmdLine.AddProperty("command",	TYPE("tcCommand")	= "C",		tcCommand,	"")
goCmdLine.AddProperty("p1",			TYPE("tcP1")		= "C",		tcP1,		"")
goCmdLine.AddProperty("p2",			TYPE("tcP2")		= "C",		tcP1,		"")
goCmdLine.AddProperty("p3",			TYPE("tcP3")		= "C",		tcP1,		"")
goCmdLine.AddProperty("p4",			TYPE("tcP4")		= "C",		tcP1,		"")
goCmdLine.AddProperty("p5",			TYPE("tcP5")		= "C",		tcP1,		"")
goCmdLine.AddProperty("p6",			TYPE("tcP6")		= "C",		tcP1,		"")
goCmdLine.AddProperty("p7",			TYPE("tcP7")		= "C",		tcP1,		"")
goCmdLine.AddProperty("p8",			TYPE("tcP8")		= "C",		tcP1,		"")
goCmdLine.AddProperty("p9",			TYPE("tcP9")		= "C",		tcP1,		"")
goCmdLine.AddProperty("p10",		TYPE("tcP10")		= "C",		tcP1,		"")



* Create the base handler object
SET PROCEDURE TO	guiClass.prg	ADDITIVE
PUBLIC goHandler
goHandler = NEWOBJECT("guiThreadHandler")


* Set the basic stuff
SET STATUS OFF
SET BELL OFF
SET DOHISTORY OFF
SET TALK OFF
SET ENGINEBEHAVIOR 70
SET STATUS BAR ON
SET SAFETY OFF


* Set the app paths
SET PROCEDURE TO	guithread.prg	ADDITIVE


* Load global variables
PUBLIC gcStartupDirectory
gcStartupDirectory = FULLPATH(CURDIR())


* Display the gui form, which calls back to the parent, and waits for the termination call from it
DO FORM frmGui


* Wait until we're done
READ EVENTS


* Upon termination, restore things
_vfp.Visible = .t.
SET TALK ON
