# Scripts
Some helpfull scripts for a variety of tasks

---------------------------------------------------------------------------------

ds4quest - a script to downsize vr videos for the Occulus Quest
The quest us now known as Meta Quest VX.
The first Quest was unable to smoothly play any vr bigger than 4096 wide
on occasion it would handle 5120 but thats about it

ds4quest will traverse a folder and non-destructively create transcoded 
copies of the files it finds.
There are command line options to override default along with a way to point it
to the directory you want it to process.

ds4quest -h will show you the options

---------------------------------------------------------------------------------

ffmpeg_build - a script to perform all the actions described at
https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu
Compile FFmpeg for Ubuntu, Debian, or Mint 

The script follows this wiki entry step by step.
It is intereactive and will ask you simple questions to do its job
Its wel commented and includes the associated wiki texst
I hope the folks at ffmpeg dont mind :)
I've also included comments about any gotchas I encountered and how I 
overcame them, if I did and appropriate comments to show what I havent overcome yet

You should read the code in one window and have the wiki page open in another
if you want to check its accuracy.
Rest assured tho, you can just create a ~/ffmpeg folder, switch to it and then
run the script in that folder it in the folder.
It will ask you if you want to perform any all or no steps and if you want it
to run all without prompting or wun them in sequence giving you the chance to bail out
after any step
The script will stop if any comilation step fails





