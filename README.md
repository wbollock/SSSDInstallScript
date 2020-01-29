# cciSSSD_AutoInstall
This is a script for Ubuntu 16.04 to auto install and setup SSSD related scripts and services. Note that you need the various configs prewritten that are scp'd.


## Prerequisites

The following files are needed and are copied to their respective locations. Put them in a file called "sssdFiles.tar.gz". They will be extracted and moved to the correct spot.

Change the "scp cci_admin1@XXX" to match your environment, or otherwise tie in the files.

They are:

chrony.conf
common-session  
nsswitch.conf  
sssd.conf
common-auth  
krb5.conf       
smb.conf


