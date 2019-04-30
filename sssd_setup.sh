#!/bin/bash
# made by William Bollock, CCI Helpdesk, April 2019
# check https://help.ubuntu.com/lts/serverguide/sssd-ad.html or the SSSD wiki page for more details
# Purpose: setup SSSD for AD auth on Ubuntu servers (tested on 16.04)
echo "Setting up SSSD. Please run this program with sudo."
echo "Updating system"
#comment out the lines below if you do not wish to update
echo ""
sudo apt update
sudo apt upgrade
sudo apt dist-upgrade
sudo apt-get autoremove
echo "Installing necessary programs - kerberos, samba, sssd, chrony"
echo "NOTICE: When prompted for Default Realm, use FSU.EDU (all caps)"
sleep 10

sudo apt install krb5-user samba sssd chrony 
echo "Editing Kerberos setup, /etc/krb5.conf"
sudo rm -f /etc/krb5.conf
scp cci_admin2@capricorn.cci.fsu.edu:~/sssd/krb5.conf /etc/krb5.conf
echo "Kerberos is now setup. Replacing chrony.conf"
sudo rm -f /etc/sssd/sssd.conf
scp cci_admin2@capricorn.cci.fsu.edu:~/sssd/chrony.conf /etc/chrony/chrony.conf

echo "Installing Samba..."
scp cci_admin2@capricorn.cci.fsu.edu:~/sssd/smb.conf /etc/samba/smb.conf

echo "Onto SSSD.conf. Replacing and reuploading."
sudo rm -f /etc/sssd/sssd.conf
scp cci_admin2@capricorn.cci.fsu.edu:~/sssd/sssd.conf /etc/sssd/sssd.conf
#note that SSSD is the file you want to edit for changing who/what groups can log onto the server
#see wiki page
echo "Changing permissions for sssd.conf"
sudo chown root:root /etc/sssd/sssd.conf
sudo chmod 600 /etc/sssd/sssd.conf

echo "Great, now we're ready to restart some services."
sudo systemctl restart chrony.service
sudo systemctl restart smbd.service nmbd.service
echo "Please enter your ADM FSUID you'd like to use when binding: "
read -r FSUID
echo "Thank you. Binding now."
sudo kinit "$FSUID"
echo "Authenticating to domain..."
sudo net ads join -U "$FSUID"@fsu.edu 
echo "It's probably okay if you get an NT_STATUS_UNSUCCESSFUL error"
sudo systemctl restart sssd.service 
echo "Editing pam.d/common-session to create a user home directory upon first login"
#TODO add SCP functionality
sudo rm -f /etc/pam.d/common-session
scp cci_admin2@capricorn.cci.fsu.edu:~/sssd/common-session /etc/pam.d/common-session


echo "All done. Please test with:"
echo "su - FSUID"
echo "The FSUID should be one that is allowed to login to the server in sssd.conf"
echo "Finally, add users to sudo with"
echo " sudo usermod -aG sudo <username> "
sleep 5
echo "Have a nice day."


#TODO: scp flag to keep file perm
#TODO: Do you want to update system? Y/N
#TODO: fix program name on wiki
#TODO: if failed binding, retry
#LDAP CONVERSION:
#note, it didn't work. No passwd entry for user web15c
#sudo apt-get purge libpam-ldap libnss-ldap ldap-utils nscd
#purge also removes config files
#CHECK TO SEE IF LDAP IS THERE
#if /etc/ldap.conf, then RUN ldap purging
# /etc/ldap.conf is overriding my stuff
# reset checkpoint back to ldap and then run stuff with purging