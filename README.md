# cciSSSD_AutoInstall
This is a script for Ubuntu 16.04 to auto install and setup SSSD related scripts and services. Note that you need the various configs prewritten that are scp'd.
Specifically for FSU's AD configuration. 

runSSSD.sh is the a version for general use. It will ask for user input.

sssd_silent.sh is a version for bulk, silent installation. It should be run with flags in the command. e.g sudo ./sssd.sh y n web15c
