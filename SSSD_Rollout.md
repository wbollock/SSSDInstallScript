# SSSD Rollout Plan


## Servers and Users that need access

Note: it is assumed that gg-cci-administrators will need access to every server. These are individual users found in /etc/ldap.conf.

Before doing these servers, email them and wait for confirmation. Schedule a restart with them, during business hours. Do Veeam quick backup instead BEFORE ldap switch. Mark down the backup before SSSD. Wait for Kyle for all them. Update wiki as you go.

Clear all getent group sudo except for cci_admin1. 

Any roger LDAP accesses, add comm-team to SSH but web-dev to SUDO

ehealthlab: zhe (gg-cci-ehealthlab)

cybersec-web: smho (ug-cci-cybersecteam)

hdweb: N/A

com4470: N/A

isensor59: smho (gg-cci-isensor)

isensor60: smho (gg-cci-isensor)

lis5472: N/A

lis3353: jhb6536 (reach out to see if he uses it)

lis2780: N/A (shut down and remove VM entirely)

**lis536x.cci.fsu.edu**: jmarks

mysql-he: zhe, sp17j (gg-cci-mysql-he)

**mysql-jowett**: mjowett, fsuEduStudentStatus=ENROLLED, fsuEduStudentStatus=C, employeeStatus=Active

Ideas: Give all instructors access in one group (gg-cci-mysql-instructors), and mysql students (gg-cci-mysql-students)



**sitemgr-prod**: rbatllelacort

staticweb1: rbatllelacort (remove him from this)
staticweb1 - Hurricanes sites: mmardis, zcl18b, cst17 (gg-cci-hurricanes)
OJS hosted on here (lit review) - check with marcia mardis first

**sitemgr2-prod**: rbatllelacort