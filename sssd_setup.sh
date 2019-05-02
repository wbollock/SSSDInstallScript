#!/bin/bash
# made by William Bollock, CCI Helpdesk, April 2019
# check https://help.ubuntu.com/lts/serverguide/sssd-ad.html or the SSSD wiki page for more details
# Purpose: setup SSSD for AD auth on Ubuntu servers (tested on 16.04)
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
BLUE='\033[0;34m'
BOLD="\033[1m"
echo -e "${BLUE}Setting up SSSD. ${BOLD}Please run this program with sudo.${NC}"
echo -e "${BLUE}${BOLD} Hit 'Enter' at all Ubuntu system prompts. Follow script prompts in ${NC}${RED}red${NC} closely."
#"here document" for use with ASCII art
#used for chaning text color

cat << "HelpDesk"
   _____ _____ _____   _    _      _       _____            _    
  / ____/ ____|_   _| | |  | |    | |     |  __ \          | |   
 | |   | |      | |   | |__| | ___| |_ __ | |  | | ___  ___| | __
 | |   | |      | |   |  __  |/ _ \ | '_ \| |  | |/ _ \/ __| |/ /
 | |___| |____ _| |_  | |  | |  __/ | |_) | |__| |  __/\__ \   < 
  \_____\_____|_____| |_|  |_|\___|_| .__/|_____/ \___||___/_|\_\
                                    | |                          
                                    |_|                      
HelpDesk
sleep (5)
read -r -n1 -p "$(echo -e $RED"(Recommended) Do you want to do a full system update? [y,n] "$NC)" doit 
case $doit in  
  y|Y) 
sudo apt --yes --force-yes update
sudo apt --yes --force-yes upgrade
sudo apt --yes --force-yes dist-upgrade
sudo apt-get --yes --force-yes autoremove
;;
  n|N) 
  printf "\n"
  echo "Ok, moving on." ;; 
  *) echo "Please try again." ;; 
esac

#looking for ldap installations, if /etc/ldap.conf found, purges ldap related programs
if [ -e /etc/ldap.conf ]; then
    read -r -n1 -p "$(echo -e $RED"(Recommended) Found LDAP installation... do you want to remove any existing LDAP-auth installation? [y,n] "$NC)" remove
    case $remove in
    y|Y) 
    printf "\n"
     sudo apt --yes --force-yes purge libpam-ldap libnss-ldap ldap-utils nscd
    ;;
    n|N) 
    printf "\n"
    echo "Ok, moving on." ;;
    *) echo "Please try again." ;; 
    esac

    else
    echo "LDAP installation not found. (etc/ldap.conf)"
    fi


printf "\n"
echo "Installing necessary programs - kerberos, samba, sssd, chrony"
sleep 10

sudo apt --yes --force-yes install krb5-user samba sssd chrony 

echo ""
echo "Copying over all SSSD components"
scp cci_admin2@capricorn.cci.fsu.edu:~/sssd/sssdFiles.tar.gz ~/sssdFiles.tar.gz

echo "Unzipping .tar.gz..."
tar -xzf sssdFiles.tar.gz



echo "Editing Kerberos setup, /etc/krb5.conf"
sudo rm -f /etc/krb5.conf
sudo mv ~/krb5.conf /etc/krb5.conf
#scp cci_admin2@capricorn.cci.fsu.edu:~/sssd/krb5.conf /etc/krb5.conf
echo "Kerberos is now setup. Replacing chrony.conf"
sudo rm -f /etc/sssd/sssd.conf
sudo mv ~/chrony.conf /etc/chrony/chrony.conf
#scp cci_admin2@capricorn.cci.fsu.edu:~/sssd/chrony.conf /etc/chrony/chrony.conf

echo "Installing Samba..."
sudo mv ~/smb.conf /etc/samba/smb.conf
#scp cci_admin2@capricorn.cci.fsu.edu:~/sssd/smb.conf /etc/samba/smb.conf

echo "Onto SSSD.conf. Replacing and reuploading."
sudo rm -f /etc/sssd/sssd.conf
sudo mv ~/sssd.conf /etc/sssd/sssd.conf
#scp cci_admin2@capricorn.cci.fsu.edu:~/sssd/sssd.conf /etc/sssd/sssd.conf
#note that SSSD is the file you want to edit for changing who/what groups can log onto the server
#see wiki page
echo "Changing permissions for sssd.conf"
sudo chown root:root /etc/sssd/sssd.conf
sudo chmod 600 /etc/sssd/sssd.conf

echo -e "${GREEN}Great, now we're ready to restart some services.${NC}"
sudo systemctl restart chrony.service
sudo systemctl restart smbd.service nmbd.service
echo ""
printf "${RED}Please enter your ADM FSUID you'd like to use when binding: ${NC}"
read -r FSUID
echo -e "${GREEN}Thank you. Creating a Kerberos ticket.${NC}"
#Kerberos ticket creation - helps verify domain login issues/binding issues
sudo kinit "$FSUID"
echo -e "${RED}Please enter in your password again. Authenticating to domain...${NC}"
sudo net ads join -U "$FSUID"@fsu.edu 
#TODO: need something to retry binding if failed password
echo "It's probably okay if you get an NT_STATUS_UNSUCCESSFUL error"
sudo systemctl restart sssd.service 

echo ""
read -r -n1 -p "$(echo -e $RED"Do you need to retry binding, for example a mistyped password(Logon failure)? [y,n] "$NC)" retry
while [ $retry -ne 'y' ];
do
printf "\n"
printf "${RED}Please enter your ADM FSUID you'd like to use when binding: ${NC}"
sudo net ads join -U "$FSUID"@fsu.edu 
sudo systemctl restart sssd.service;
done


echo "Editing pam.d/common-session to create a user home directory upon first login"
#sudo rm -f /etc/pam.d/common-session
sudo mv ~/common-session /etc/pam.d/common-session
#scp cci_admin2@capricorn.cci.fsu.edu:~/sssd/common-session /etc/pam.d/common-session

echo "Overriding old nsswitch.conf"
sudo mv ~/nsswitch.conf /etc/nsswitch.conf
#scp cci_admin2@capricorn.cci.fsu.edu:~/sssd/nsswitch.conf /etc/nsswitch.conf

echo "Running pam-auth-update to force SSSD usage, instead of LDAP"
sudo pam-auth-update --force
#user will just hit enter for this

echo ""
echo -e "${GREEN}All done. Binding complete.${NC} Please test with:"
echo "su - FSUID"
printf "\n"
echo "Finally, add users to sudo with:"
echo "sudo usermod -aG sudo <username>"
# add list of users to add to sudo
echo -e "${BLUE}Have a nice day!${NC}"



#TODO: update wiki with other config 
# and additional files with <hidden> and </hidden>
# y's only installatiin/purge
# TODO:
# do you have any users (or groups?!) to add to sudo
# 203136909(gg-cci-helpdesk)
# list of users, possibly seperated by comma
# dynamic array 
# TODO:
# how to run bash commands remotely (update servers remotely)
# TESTING 
# test without ldap
# test w/ virtualmin and ldap