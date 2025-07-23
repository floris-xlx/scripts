- go to system settings
- go to advanced system settigns
- click on environment variables on the bottom right
- change all the User and System temp & tmp folderpaths to a custom one
--- nvm just delayed the error
  # bump unsolved

Try this before you do anything else. It's easy. - From your windows search bar do MSCONFIG. Click the boot tab. Click Advanced. Check the box for number of processors and set limit it to 1 or 2. Reboot. Save your changes. Reboot the computer. Try to reinstall again. After successful install, go back in and uncheck the number of processors to put it back to full performance.

-worked for me-

WHY THIS WORKED FOR ME: I have heard that one reason these CRC errors are popping up in the NVIDIA installer is that some recent intell chips have cores that are generating this issue. [I can't validate this]. Reducing the number of cores temporarily may let you bypass the core that is causing the software to generate the CRC error.

I went around and around before finding this solution. I uninstalled/reinstalled Nvidia, 7-sip, etc... tried as admin, tried in safe made, did a complete wipe of windows and reloaded - nothing worked for me until i found this. I hope it helps others.
