#!/bin/bash
# made by William Bollock, CCI Helpdesk, April 2019
# check https://help.ubuntu.com/lts/serverguide/sssd-ad.html or the SSSD wiki page for more details
# Purpose: setup SSSD for AD auth on Ubuntu servers (tested on 16.04)
function upgrade {
  case $1 in  
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
}


function ldap {
  case $1 in
    y|Y) 
    printf "\n"
     sudo cp /etc/ldap.conf /home/cci_admin1/ldap.conf.SSSDBAK
     sudo apt --yes --force-yes purge libpam-ldap libnss-ldap ldap-utils nscd
    ;;
    n|N) 
    printf "\n"
    echo "Ok, moving on." ;;
    *) echo "Please try again." ;; 
    esac

    
}


#command line arguments
#./sssd.sh y n web15c

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
BLUE='\033[0;34m'
BOLD="\033[1m"
YELLOW='\033[0;33m'
echo -e "${BLUE}Setting up SSSD. ${BOLD}Please run this program with sudo.${NC}"
echo -e "${BLUE}${BOLD}**Hit 'Enter' at all Ubuntu system prompts**. Follow script prompts in ${NC}${RED}red${NC} ${BLUE}${BOLD}closely.${NC}"
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
sleep 3
read -r -n1 -p "$(echo -e $RED"(Recommended) Do you want to do a full system update? [y,n] "$NC)" doit 
upgrade $doit

#looking for ldap installations, if /etc/ldap.conf found, purges ldap related programs
if [ -e /etc/ldap.conf ]; then
    read -r -n1 -p "$(echo -e $RED"(Recommended) Found LDAP installation... do you want to remove any existing LDAP-auth installation? [y,n] "$NC)" remove
    ldap $remove
    else
    echo "LDAP installation not found. (etc/ldap.conf)"
    fi


printf "\n"
echo -e "${BLUE}Installing necessary programs - kerberos, samba, sssd, chrony${NC}"
sudo DEBIAN_FRONTEND=noninteractive apt --yes --force-yes install krb5-user samba sssd chrony 
#DEBIAN_FRONTEND=noninteractive gets rid of the purple package management screen

echo ""
echo "Copying over all SSSD components"
scp cci_admin1@servermgr.cci.fsu.edu:~/sssd/sssdFiles.tar.gz ~/sssdFiles.tar.gz
#if this scp fails, the entire script fails
echo "Unzipping .tar.gz..."
tar -xzf sssdFiles.tar.gz



echo "Editing Kerberos setup, /etc/krb5.conf"
sudo rm -f /etc/krb5.conf
sudo mv ~/krb5.conf /etc/krb5.conf

echo "Kerberos is now setup. Replacing chrony.conf"
sudo rm -f /etc/sssd/sssd.conf
sudo mv ~/chrony.conf /etc/chrony/chrony.conf


echo "Installing Samba..."
sudo mv ~/smb.conf /etc/samba/smb.conf


echo "Onto SSSD.conf. Replacing and reuploading."
sudo rm -f /etc/sssd/sssd.conf
sudo mv ~/sssd.conf /etc/sssd/sssd.conf

#note that sssd.conf is the file you want to edit for changing who/what groups can log onto the server

echo "Changing permissions for sssd.conf"

sudo chown root:root /etc/sssd/sssd.conf
sudo chmod 600 /etc/sssd/sssd.conf

echo -e "${GREEN}Great, now we're ready to restart some services.${NC}"
sudo systemctl restart chrony.service
sudo systemctl restart smbd.service nmbd.service
echo ""

printf "${RED}Please enter your ADM FSUID you'd like to use when binding: ${NC}"
read -r FSUID

echo -e "${RED}Please enter in your password again. Authenticating to domain...${NC}"
sudo net ads join -U "$FSUID"@fsu.edu 
echo -e "${YELLOW}It's OK if you get an NT_STATUS_UNSUCCESSFUL error. This does not affect binding.${NC}"
echo -e "${YELLOW}However, a Logon Failure means the binding has failed.${NC}"
sudo systemctl restart sssd.service 

echo ""


printf "\n"



echo "Overriding old nsswitch.conf"
sudo mv ~/nsswitch.conf /etc/nsswitch.conf


echo "Running pam-auth-update to force SSSD usage, instead of LDAP"
sudo pam-auth-update --force
#user will just hit enter for this
#BUG: sometimes hangs?

echo "Replacing PAM common-session file."
sudo mv ~/common-session /etc/pam.d/common-session

echo "Replacing PAM common-auth file."
sudo mv ~/common-auth /etc/pam.d/common-auth


#automatic bind checker
echo -e "${BLUE}Testing your bind with [id km12n]${NC}"
# if the output of id km12n has a sufficient output, then binding works!
var="$(id km12n)"
id_array=("$var")
id_array_length=${#id_array}
if [ $id_array_length -gt 27 ]; then
  #27 because id km12n that doesn't work is ~26 characters
  echo -e "${GREEN}Bind ${BOLD}succeeded${NC}${GREEN}. id km12n returned sufficent length.${NC}"
  else
  echo -e "${RED}Bind ${BOLD}failed${NC}${RED}. id k12mn was too short.${NC}"
fi

while :
do
  read -r -n1 -p "$(echo -e $RED"Do you need to retry binding, for example a mistyped password(Logon failure)? [y,n] "$NC)" retry
  if [ $retry = n ];
  then
  break
  fi
  printf "\n"
  #printf "${RED}Please enter your ADM FSUID you'd like to use when binding: ${NC}"
  sudo net ads join -U "$FSUID"@fsu.edu 
  #uses same FSUID as before
  sudo systemctl restart sssd.service
  #Kerberos ticket creation - helps verify domain login issues/binding issues
  #echo -e "${GREEN}Thank you. Creating a Kerberos ticket. Not necessary for binding, but useful for debugging.${NC}"
  #sudo kinit "$FSUID"
  printf "\n"
done

echo ""
echo -e "${GREEN}All done. Binding complete.${NC} Please test with:"
echo "su - FSUID"
printf "\n"
echo -e "${RED}Adding ${BOLD}gg-cci-administrators${NC}${RED} to sudoers${NC}"
# hard coded administrators in
sudo echo "%gg-cci-administrators ALL=(ALL)ALL" | sudo tee -a /etc/sudoers
exit
# will exit program if sudo not given to program originally

echo -e "${RED} Fixing /home/ permissions and ownership${NC}"

# For each folder in /home/*/
# if user or group = NUMBER, then 
# sudo chown -R $folder_name:'domain users' /home/*/
# sudo chmod 700 /home/*/

# DO NOT PARSE LS

for file in /home/*; do
    
    user=$(stat -c "%U" $file) # find user of file

    # determine if $file is a number
    #re='^[0-9]+$'
    if [[ $user = UNKNOWN ]] ; then
    echo "$file's permissions are being changed..."
      #then user is a number and should be converted
      fileExact=$(echo $file | sed -e 's#/home/##g')
      # purge the /home/ from it

      # Note: echo "/home/web15c/" | sed -e 's#/home/##g'
      # spits out: web15c/

      sudo chown -R $fileExact:'domain users' $file
    fi
    sudo chmod 700 $file

done



echo $(ls -l /home/)
echo -e "${GREEN} Does this look right?${NC}"



echo -e "${BLUE}Have a nice day!${NC}"
sudo rm -rf sssd.sh

#echo -e "${BLUE} Would you like to reboot the server?${NC}"
# if not, SCHEDULE A REBOOT
## TODO:
# ask if you'd like to reboot the server

# TODO:
# how to run bash commands remotely (update servers remotely)
# get list of servers and have a script use those to then run command 
# make sure sssd_silent.sh and sssd_setup.sh are synced


# EXISTING USER ACCOUNTS NEED HOME FOLDER PERMISSION SWITCHED:

# sudo chown -R "web15c:domain users" /home/web15c/
# sudo chmod 700 /home/web15c


# https://sourceforge.net/p/webadmin/discussion/600155/thread/5bdffa8d/
#https://sourceforge.net/p/webadmin/discussion/55378/thread/cc75efed/
#https://www.virtualmin.com/node/66746