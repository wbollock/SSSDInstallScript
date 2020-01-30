#!/bin/bash
# made by William Bollock, CCI Helpdesk, April 2019
# Purpose: setup SSSD for AD auth on Ubuntu servers (tested on 16.04)


function upgrade {
  case $1 in  
  y|Y) 
  sudo apt --yes --allow-downgrades --allow-remove-essential --allow-change-held-packages update
  sudo apt --yes --allow-downgrades --allow-remove-essential --allow-change-held-packages upgrade
  # used to update system
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
     sudo cp /etc/ldap.conf /etc/ldap.conf.SSSDBAK
     sudo apt --yes --allow-downgrades --allow-remove-essential --allow-change-held-packages purge libpam-ldap libnss-ldap ldap-utils nscd
     # used to backup and remove ldap files
    ;;
    n|N) 
    printf "\n"
    echo "Ok, moving on." ;;
    *) echo "Please try again." ;; 
    esac

    
}

# CONFIG VARIABLES
logLocation=/var/log/sssdInstall.log

# Pipe Date into start of log
echo "SSSD Install Log" | tee -a $logLocation
echo $(date) | tee -a $logLocation
echo "" | tee -a $logLocation


# used for chaning text color

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
BLUE='\033[0;34m'
BOLD="\033[1m"
YELLOW='\033[0;33m'

echo -e "${BLUE}Setting up SSSD. ${BOLD}Please run this program with sudo.${NC}"
echo -e "${BLUE}There will be a log avaiable in $logLocation ${NC}"
echo -e "${BLUE}${BOLD}**Hit 'Enter' at all Ubuntu system prompts**. Follow script prompts in ${NC}${RED}red${NC} ${BLUE}${BOLD}closely.${NC}"
# "here document" for use with ASCII art


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
sudo DEBIAN_FRONTEND=noninteractive apt --yes install krb5-user samba sssd chrony 
#DEBIAN_FRONTEND=noninteractive gets rid of the purple package management screen

echo ""
echo "Copying over all SSSD components"
scp cci_admin1@servermgr.cci.fsu.edu:~/sssd/sssdFiles.tar.gz ~/sssdFiles.tar.gz
# if this scp fails, the entire script fails
# TODO: replace this method with a private git repo and git clone
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

# note that sssd.conf is the file you want to edit for changing who/what groups can log onto the server

echo "Changing permissions for sssd.conf"
# must be 600
sudo chown root:root /etc/sssd/sssd.conf
sudo chmod 600 /etc/sssd/sssd.conf

echo -e "${GREEN}Great, now we're ready to restart chrony, smbd, and nmbd.${NC}"
sudo systemctl restart chrony.service
sudo systemctl restart smbd.service nmbd.service
echo ""

printf "${RED}Please enter your ADM FSUID you'd like to use when binding: ${NC}"
read -r FSUID

echo "$FSUID used as FSUID when binding" | tee -a $logLocation

echo -e "${RED}Please enter in your password again. Authenticating to domain...${NC}"
# REALMD:
# sudo realm join fsu.edu -U adm-cci-web15c --install=/
# another alternative to this
sudo net ads join -U "$FSUID"@fsu.edu 
echo -e "${YELLOW}It's OK if you get an NT_STATUS_UNSUCCESSFUL error. This does not affect binding.${NC}"
echo -e "${YELLOW}However, a Logon Failure means the binding has failed.${NC}"
sudo systemctl restart sssd.service 

echo ""


printf "\n"



echo "Overriding old nsswitch.conf"
sudo mv ~/nsswitch.conf /etc/nsswitch.conf


echo -e "${RED}**ATTENTION**: Use the spacebar to select \'Create home directories on login\' on the next screen${NC}"
sleep 10



echo "Running pam-auth-update to force SSSD usage, instead of LDAP"
sudo pam-auth-update --force
# make sure to select create home directories


echo "Replacing PAM common-session file."
sudo mv ~/common-session /etc/pam.d/common-session

echo "Replacing PAM common-auth file."
sudo mv ~/common-auth /etc/pam.d/common-auth


#automatic bind checker
echo -e "${BLUE}Testing your bind with [id cci-service]${NC}"
# if the output of id cci-service has a sufficient output, then binding works!
var="$(id cci-service)"
id_array=("$var")
id_array_length=${#id_array}
if [ $id_array_length -gt 40 ]; then
  # 40 because id cci-service that doesn't work is 31 characters
  echo -e "${GREEN}Bind ${BOLD}succeeded${NC}${GREEN} (id cci-service returned sufficent length)${NC}"
  else
  echo -e "${RED}Bind ${BOLD}failed${NC}${RED} (id cci-service was too short)${NC}"
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
echo -e "${GREEN}All done. Binding complete.${NC}"

printf "\n"
echo -e "${BLUE}Adding ${BOLD}gg-cci-administrators${NC}${BLUE} to sudoers${NC}"
# hard coded administrators in
echo "%gg-cci-administrators ALL=(ALL)ALL" | sudo tee -a /etc/sudoers




# For each folder in /home/*/
# if user or group = NUMBER, then 
# sudo chown -R $folder_name:'domain users' /home/*/
# sudo chmod 700 /home/*/

# DO NOT PARSE LS


echo -e "${BLUE}Fixing /home/ permissions and ownership${NC}"
sleep 2

# https://linuxhandbook.com/bash-split-string/
# every standard user/group to filter
filterString="root,www-data,sshd,snmp,bin,clamav,daemon,ntp,postfix,Debian-exim,amavis,backup,bind,debian-spamd,dovecot,dovenull,games,gnats,irc,landscape,libuuid,list,lp,mail,man,messagebus,mysql,nagios,news,postgrey,proxy,smmsp,smmta,statd,sync,sys,syslog,uucp,vmail,whoopsie"
IFS=',' read -ra filterArray <<< $filterString


# convert string to array, delimited by the commas

for file in /home/*; do
    
    user=$(stat -c "%U" $file) # find user of filesudo
    group=$(stat -c "%G" $file)
    
    # if the user part of the home folder is a number (UNKNOWN), then we know it's an existing ldap user
    if [[ $user = UNKNOWN ]] ; then
      #then user is a number and should be converted
      fileExact=$(echo $file | sed -e 's#/home/##g')
      # purge the /home/ from it
      echo -e "${GREEN}Domain user $fileExact's home directory permissions are being corrected...${NC}" | tee -a $logLocation
      # Note: echo "/home/web15c/" | sed -e 's#/home/##g'
      # spits out: web15c/
      sudo chown -R $fileExact:'domain users' $file
      sudo chmod 700 $file 
    elif [ "$group" == "domain users" ] ; then
      test
      # skip SSSD users that already have their proper group
    else
      # all other users must be local accounts
        filterArray+=("$user")
       # add new items to array - in the loop
    fi
done

# convert back to string outside of loop at append filter_user / filter_group to the file
printf -v filterStringFull ',%s' "${filterArray[@]}"

# get rid of leading ,
filterStringFull=${filterStringFull:1}

# the whole NSS section of the conf file is built from here. It should not be hard coded into sssd.conf
echo "# Filtered users generated from sssd.sh" | sudo tee -a /etc/sssd/sssd.conf $logLocation
echo "[nss]" | sudo tee -a /etc/sssd/sssd.conf $logLocation
echo "reconnection_retries = 3" | sudo tee -a /etc/sssd/sssd.conf $logLocation
echo "filter_users = $filterStringFull" | sudo tee -a /etc/sssd/sssd.conf $logLocation
echo "filter_groups = $filterStringFull" | sudo tee -a /etc/sssd/sssd.conf $logLocation

echo "" | tee -a $logLocation
echo "" | tee -a $logLocation

    
sudo rm sssd.sh

sudo systemctl restart sssd
sudo systemctl status sssd

echo -e "${BLUE}Have a nice day! **Do not forget to restore ssh access to users**${NC}"




