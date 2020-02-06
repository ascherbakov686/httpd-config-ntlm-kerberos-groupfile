#!/bin/bash

#
# dependencies packages:
# patch, diff, openldap-clients
#

home="/etc/httpd/conf"
f1="/etc/httpd/conf/httpd-access-groups-kerberised4.update";
f2="/etc/httpd/conf/httpd-access-groups-kerberised4.prev";
f3="/etc/httpd/conf/httpd-access-groups-kerberised4";
f4="/etc/httpd/conf/httpd-access-groups-kerberised4.patch";
f5="/etc/httpd/conf/httpd-access-groups-kerberised4.curr";
f6="/etc/httpd/conf/httpd-access-groups-kerberised-admins4";
f7="/etc/httpd/conf/httpd-access-groups-kerberised-admin-users4";

cat /dev/null > $f1;
cp -f $f3 $f2

grps=("esearch-restrict-grp1,OU=Groups,OU=Clients,DC=domain,DC=ru" 
"esearch-restrict-grp2,OU=Groups,OU=Clients,DC=domain,DC=ru" 
"esearch-restrict-grp3,OU=Groups,OU=Clients,DC=domain,DC=ru");


for group in "${grps[@]}"; do

indx=0;

count_all=0;

filter="(&(objectCategory=user)(|";

filter="$filter(memberOf=CN=$group)";

filter="$filter))";

str=$(echo $group | cut -d ',' -f 1)": "

#debug
echo $str


dn="CN=lblsrv,OU=Accounts,OU=Hosting,DC=domain,DC=ru";
secret=$(cat $home/.hidden.lck | openssl enc -base64 -d -aes-256-cbc -nosalt -pass pass:***********************);
members=();
domains=();

#listing trusted domains
#for domain in $(wbinfo --online-status | grep online | cut -d ':' -f 1); do
for domain in $(wbinfo -m); do

#read domain suffix
suffix=$(wbinfo --domain-info=$domain | grep Alt_Name | cut -d ':' -f 2 | tr -d '[[:space:]]' );
#read domain controller server name
controller=$(wbinfo --getdcname=$domain |& grep -iv 'could' | tr -d '[[:space:]]'); 

#making distinguishedName from suffix name
base=$(echo "$suffix" | sed 's/\./',dc='/g');
base="dc=$base";

#generating array of ldap requests command strings
if [ "$controller" != "" ]; then

echo "$domain ${controller,,}.$suffix $base";
members+=("$(ldapsearch -o nettimeout=30 -x -LLL -h ${controller,,}.$suffix -p 389 -D "$dn" -w$secret -b "$base" "$filter" "sAMAccountName" |& grep "sAMAccountName:" | cut -d ':' -f 2)");
domains+=("$domain");

fi;

done;



for ms in "${members[@]}"
do

#debug
echo $ms

count=$(wc -l <<< "$ms");
(( count_all += $count ));

for m in $ms;
do
  #original case
  str=("$str ${domains[indx]}\\$m");
  #lowercase
  str=("$str ${domains[indx]}\\${m,,}");
done;

(( indx++ ));

done;

echo "$str" >> $f1;

done;


#patching
if [ $count_all -ge 1 ]; then
    diff $f3 $f1 > $f4;
    patch $f3 -i $f4 -o $f5;
    cp -f $f5 $f3;
fi;




#########
######### echo '*********************' | openssl enc -base64 -e -aes-256-cbc -nosalt  -pass pass:***************** > .hidden.lck
#########
