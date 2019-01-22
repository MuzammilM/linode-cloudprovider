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

function createLinode(){
grp=$1
ip=$(linode-cli linodes create --root_pass --region ap-south --image $linImage --group $grp --type $linType --authorized_keys "`cat ~/.ssh/id_rsa.pub`" --label $label --no-header --format 'ipv4' | awk '{print $2}')
ip2=`echo $ip | sed -e 's/ //g'`
sudo sed  -i '/\['"$grp"'\]/a '"$label"' ansible_ssh_host='"$ip2"'' /etc/ansible/hosts
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
