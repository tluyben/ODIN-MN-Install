#!/bin/bash


TARBALLURL="http://139.59.167.251/odin.zip"
TARBALLNAME="odin.zip"
BWKVERSION="1.2.4.0"

CHARS="/-\|"

clear
echo "This script will update your masternode to version $BWKVERSION"
read -p "Press Ctrl-C to abort or any other key to continue. " -n1 -s
clear

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root."
  exit 1
fi

USER=`ps u $(pgrep odind) | grep odind | cut -d " " -f 1`
USERHOME=`eval echo "~$USER"`

echo "Shutting down masternode..."
if [ -e /etc/systemd/system/odind.service ]; then
  systemctl stop odind
else
  su -c "odin-cli stop" $USER
fi

echo "Installing ODIN $BWKVERSION..."
mkdir ./odin-temp && cd ./odin-temp
wget $TARBALLURL
unzip $TARBALLNAME
chmod 755 odin*
yes | cp -rf ./odind /usr/local/bin
yes | cp -rf ./odin-cli /usr/local/bin
cd ..
rm -rf ./odin-temp

if [ -e /usr/bin/odind ];then rm -rf /usr/bin/odind; fi
if [ -e /usr/bin/odin-cli ];then rm -rf /usr/bin/odin-cli; fi
if [ -e /usr/bin/odin-tx ];then rm -rf /usr/bin/odin-tx; fi

sed -i '/^addnode/d' $USERHOME/.odin/odin.conf

echo "Restarting ODIN daemon..."
if [ -e /etc/systemd/system/odind.service ]; then
  systemctl start odind
else
  cat > /etc/systemd/system/odind.service << EOL
[Unit]
Description=odind
After=network.target
[Service]
Type=forking
User=${USER}
WorkingDirectory=${USERHOME}
ExecStart=/usr/local/bin/odind -conf=${USERHOME}/.odin/odin.conf -datadir=${USERHOME}/.odin
ExecStop=/usr/local/bin/odin-cli -conf=${USERHOME}/.odin/odin.conf -datadir=${USERHOME}/.odin stop
Restart=on-abort
[Install]
WantedBy=multi-user.target
EOL
  sudo systemctl enable odind
  sudo systemctl start odind
fi
clear

echo "Your masternode is syncing. Please wait for this process to finish."

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

su -c "odin-cli masternode status" $USER

cat << EOL

Masternode update completed.

EOL
