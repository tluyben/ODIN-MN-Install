#!/bin/bash

clear
echo "This script will refresh your masternode."
read -p "Press Ctrl-C to abort or any other key to continue. " -n1 -s
clear

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root."
  exit 1
fi

USER=`ps u $(pgrep odind) | grep odind | cut -d " " -f 1`
USERHOME=`eval echo "~$USER"`

if [ -e /etc/systemd/system/odind.service ]; then
  systemctl stop odind
else
  su -c "odin-cli stop" $BWKUSER
fi

echo "Refreshing node, please wait."

sleep 5

rm -rf $USERHOME/.odin/blocks
rm -rf $USERHOME/.odin/database
rm -rf $USERHOME/.odin/chainstate
rm -rf $USERHOME/.odin/peers.dat

cp $USERHOME/.odin/odin.conf $USERHOME/.odin/odin.conf.backup
sed -i '/^addnode/d' $USERHOME/.odin/odin.conf

if [ -e /etc/systemd/system/odind.service ]; then
  sudo systemctl start odind
else
  su -c "odind -daemon" $USER
fi

echo "Your masternode is syncing. Please wait for this process to finish."
echo "This can take up to a few hours. Do not close this window." && echo ""

until su -c "odin-cli mnsync status 2>/dev/null | grep '\"IsBlockchainSynced\" : true' > /dev/null" $USER; do
  for (( i=0; i<${#CHARS}; i++ )); do
    sleep 2
    echo -en "${CHARS:$i:1}" "\r"
  done
done

clear

cat << EOL

Now, you need to start your masternode. Please go to your desktop wallet and
enter the following line into your debug console:

startmasternode alias false <mymnalias>

where <mymnalias> is the name of your masternode alias (without brackets)

EOL

read -p "Press Enter to continue after you've done that. " -n1 -s

clear

sleep 1
su -c "/usr/local/bin/odin-cli startmasternode local false" $USER
sleep 1
clear
su -c "/usr/local/bin/odin-cli masternode status" $USER
sleep 5

echo "" && echo "Masternode refresh completed." && echo ""
