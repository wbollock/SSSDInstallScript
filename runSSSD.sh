#!/bin/bash
#example to run script 20 times on 20 different servers
server_list=servers.txt
#needs to just be the first name of them
# does not include the script
for server in $(cat $server_list)
do
    #scp cci_admin2@capricorn.cci.fsu.edu:~/sssd/sssdFiles.tar.gz cci_admin1@$server.cci.fsu.edu:~/sssdFiles.tar.gz
    scp cci_admin2@capricorn.cci.fsu.edu:~/sssd/sssd.sh cci_admin1@$server.cci.fsu.edu:~/sssd.sh
done
#make a new tar.gz first if it doesn't have .sh
# who knows if this will work
for server in $(cat $server_list)
do
ssh -t cci_admin2@$server.cci.fsu.edu 'sudo ~/./sssd.sh y n web15c'
echo $server
done

#scp cci_admin2@capricorn.cci.fsu.edu:~/sssd/sssd.sh cci_admin2@leo.cci.fsu.edu:~/sssd.sh

#!/bin/bash
# scp from local to remote
scp /home/wbollock/projects/cciSSSD_AutoInstall/sssd_silent.sh cci_admin2@leo.cci.fsu.edu:~/sssd.sh
ssh -t cci_admin2@leo.cci.fsu.edu 'sudo chmod +x sssd.sh && sudo ./sssd.sh y n web15c'