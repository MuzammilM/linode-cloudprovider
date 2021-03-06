# Provisions a linode instance via the cli and adds to ansible ssh host
# Author: MuzammilM
ERROR="\033[0;31m"
WARN="\033[0;33m"
SUCCESS="\033[0;32m"
DEFAULT="\033[0;37m"
reset=`tput sgr0`

if ! [ -x "$(command -v linode-cli)" ];
then
pip install linode-cli --upgrade
echo "${ERROR}Please configure the cli first ${reset}"
exit
fi

if ! [ -x "$(command -v jq)" ];
then
sudo apt-get install -y jq
echo "${WARN}Installing jq ${reset}"
exit
fi

function listStackScripts(){
token=$1
user=$2
echo "User : "$user
curl -s "https://api.linode.com/v4/linode/stackscripts" -H 'Authorization: Bearer '$token'' -H 'X-Filter: { "username": "'$user'"}' | jq '[.data[] | {id:.id,label:.label,description:.description}]'
}

function createLinode(){
grp=$1
echo "Use Linode StackScripts ?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) echo "Available scripts :" ; read -esrp"Enter LINODE TOKEN " TOKEN ; read -erp"Enter LINODE username " USERNAME; listStackScripts $TOKEN $USERNAME ; read -erp"Enter scriptid " scriptid ; ip=$(linode-cli linodes create --root_pass --region ap-south --image $linImage --group $grp --type $linType --authorized_keys "`cat ~/.ssh/id_rsa.pub`" --label $label --no-header --stackscript_id $scriptid --format 'ipv4' | awk '{print $2}'); break;;
        No ) ip=$(linode-cli linodes create --root_pass --region ap-south --image $linImage --group $grp --type $linType --authorized_keys "`cat ~/.ssh/id_rsa.pub`" --label $label --no-header --format 'ipv4' | awk '{print $2}'); break;;
    esac
done
ip2=`echo $ip | sed -e 's/ //g'`
sudo sed  -i '/\['"$grp"'\]/a '"$label"' ansible_ssh_host='"$ip2"'' /etc/ansible/hosts
echo -e "Host "$label"\nUser root\nHostname "$ip2 >> .ssh/config
echo "New machine ip :"$ip2
}
read -erp"Enter ansible/linode group name(Eg: Spark) " gname
read -erp"Enter label to assign to the server(Eg: Zeus) " label
linode-cli images list
read -erp"Enter image to be used " linImage
linode-cli linodes types
read -erp"Enter instance type " linType
if grep -q "\[$gname\]" /etc/ansible/hosts;
then
createLinode $gname
else
echo "Group not available ; create a new group called "$gname" ?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) echo "["$gname"]" | sudo tee -a "/etc/ansible/hosts"; createLinode $gname ; break;;
        No ) echo "Available groups :" ; cat /etc/ansible/hosts | grep "\[" ; read -erp"Enter from available group names " ngrp ; createLinode $ngrp ; break;;
    esac
done
fi
