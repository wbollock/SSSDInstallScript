#!/bin/bash
# scp from local to remote
scp /home/wbollock/projects/cciSSSD_AutoInstall/sssd_silent.sh cci_admin2@leo.cci.fsu.edu:~/sssd.sh
ssh -t cci_admin2@leo.cci.fsu.edu 'sudo chmod +x sssd.sh && sudo ./sssd.sh y n web15c'
