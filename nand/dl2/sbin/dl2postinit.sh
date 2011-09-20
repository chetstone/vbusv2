cp /mnt/nand/root/* /root
crontab /mnt/nand/root/cronspecs -u root
cd /root;./no-ip.sh
