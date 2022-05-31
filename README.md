## **OBS Window Switcher**

Automatically switches a Window Capture Source to a new window when the currently captured window is closed.

\
**HOW TO USE**
1. Import script into obs-studio (Tools/Scripts)
2. Select the target sources in the dropdowns.

*Pro tip: Make sure to set all the target sources Window Match Priority to 'Window title must match'.*

\
**EXAMPLE USE CASE**

The original intent of this script is to automatically switch poker tables in the event of one closing, for example a table exit in a cash game or when you bust a tournament. I really think this improves quality of life for poker streaming as well as less need to focus configuring the stream sources, essentially making the streamer gain expected value.

\
**TO DO**
1. Dynamically add or remove number of possible target sources.
2. Dynamically change the target window class and executable.
3. The possibility to add more than one target class and executable (e.g., to target multiple poker sites).
4. Add start/stop button.
5. Fix crashing on exit.
