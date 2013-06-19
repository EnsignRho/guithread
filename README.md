To run the example
========

1. Open VFP9
2. Navigate to .\master\
3. Type "DO go"

The screen that comes up is the master application.  Click the launch button to
launch a window in that direction (relative to where it is on the master).  Each
launch spawns a new slave process running its own instance of VFP9.  The slave and
master have two-way communication to allow coordinated movement, as well as the
reporting of countdown information, along with termination information.

This template example can be used as a base and expanded upon to handle any GUI
need.  Note that the slave.prg command line receives information used specifically
for the coordination between master and slave.  This point is essential.


History
--------
If an application supports threading, it is easy to do multiple things simulatenously.
You would simply spawn a new thread for each new thing.  However, when using a system
which is only a single-thread system, special techniques must be employed to coax the
system into doing multiple things in parallel.

In Windows there are a few ways to do this.  The easiest is to spawn separate processes,
each of which will run in its own memory area, isolated from other processes.  So, the
question then becomes:  how do you control another process.

Visual FoxPro natively provides mechanisms to make this happen.  It is the BINDEVENT()
function used in combination with a form's hwnd property (thisForm.hwnd).

To understand BINDEVENT is is necessary to understand how Windows works internally.
Every window that the user sees (visible windows, like the email or text editor you're
viewing this file in right now) continually receives a stream of messages from the
Windows kernel and its drivers.  Keystrokes are translated into messages which are
passed to the window via something called a WndProc (pronounced "wind prock", and it
is a "windows procedure").  The WndProc receives all messages, and then, based on the
message, does things.  It records mouse movements, checking to see if the mouse pointer
needs to change when it goes over some defined object on the window, or keystrokes then
go to whatever has keystroke focus, etc.

Above these standard Windows-based messages are a group called user-messages.  They
begin at the number 1024 and extend upward to 32-bits (nearly 4.3 billion messages).
Custom applications can use these messages to instruct other processes to do things
by locating that process's window, and sending it messages.  The BINDEVENT ability
allows VFP9 code to intercept those messages and then do something useful with it.

So, the question is we have a master app, and a slave app, and we want to send the
slave app certain messages to do things, but we won't know what its hwnd value is
until it loads and creates its own form.  So, how do we find that when we might be
running 20 or more slaves simultaneously?  It's the chicken-and-the-egg scenario as
applied to multiple processes.

Fortunately, there is an easy workaround.  We simply prepare a table or file with
the information about us (the master app) that the slave will need to know to conduct
its work.  Then, we pass (as a command line parameter to the new process we'll be
launching) the name of that file.  Then, the slave opens up that file and one of the
pieces of information contained within is the hwnd of the master's form, to which a
BINDEVENT has already been setup on the message number that the slave will send back.

Windows allows two extra pieces of information (32-bit quantities) to also be passed
along with the message number.  So, one of them can be the ID of the instance that is
"reporting in to its master," and the other can be its status, such as "1" for launched,
"2" for processing and "3" for exiting.  It can be whatever you need.  In some cases it
might be desirable to have feedback to the parent from time to time about the percent
completed.  Et cetera.  The sky's the limit.

So, the general design becomes:

(1)  The master app.  This application prepares data portions which will be sent out
     to each slave app.  It contains information about all the files it will need,
     tables, report names, whatever, along with the hwnd of the form used for multi-
     process coordination.
     
(2)  The slave app.  This application receives a single command line parameter which
     is the name of the table or file to open.  It reads the data contained within
     and sends back a message to the hwnd provided by the master.  This lets the master
     app know that it is up and running, and is processing data.  When it later
     receives the "I'm now exiting" message, it knows it can launch a new process to
     keep the processors/cores full of work to do.

In concept, the general execution model is this simple.  It's up to each instance needing
multiple processes to determine the protocols necessary to make what needs to happen
actually happen.

Please feel free to ask any questions.  Also, examining the sample master and slave
apps contained in this directory will give you explicit insight into how to make
this process work as these are functioning, self-contained examples.  Simply take
what's in master and apply it to your app.  And then take what's in slave, copy it
for your individual needs, and modify those copies to do whatever tasks are required.

Best regards,
Rick C. Hodgin
rick.c.hodgin@gmail.com

