#!/bin/bash
#example to run script 20 times on 20 different servers
server_list=servers.txt
#needs to just be the first name of them
for server in $(cat $server_list)
do
    scp cci_admin2@capricorn.cci.fsu.edu:~/sssd/sssdFiles.tar.gz cci_admin1@$server.cci.fsu.edu:~/sssdFiles.tar.gz
done
#make a new tar.gz first if it doesn't have .sh
# who knows if this will work
for server in $(cat $server_list)
do
ssh -t cci_admin2@$server.cci.fsu.edu 'sudo ./sssd.sh y n web15c'
echo $server
done