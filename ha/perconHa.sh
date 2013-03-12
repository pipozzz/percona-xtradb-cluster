#!/bin/bash
# Needed : mysql -e "CREATE USER 'perconha'@'localhost' IDENTIFIED BY 'secret'; FLUSH PRIVILEGES;"

MYSQLHOST='localhost'
MYSQLPORT='3306'
MYSQLUSER='perconha'
MYSQLPASS='secret'

VIPRO='127.0.0.2/32'
VIPRW='127.0.0.3/32'

ETH='eth1'

vip() {
	if [ -f '/etc/perconHa/RW' ]; then
		if [ `nc $VIPRW 3306 -w 1` -eq 0 ]; then
			ifconfig $ETH:1 $VIPRW
		fi
	else
		ifconfig $ETH:1 $VIPRW down &> /dev/null
	fi
	if [ -f '/etc/perconHa/RO' ]; then
		if [ `nc $VIPRO 3306 -w 1` -eq 0 ]; then
			ifconfig $ETH:2 $VIPRO
		fi
	else
		ifconfig $ETH:2 $VIPRO down &> /dev/null
	fi
}

# is MySQL running ?
if [ `ps aux | grep mysqld | wc -l` -eq 0 ]; then
	# DEAD
	ifconfig $ETH:1 $VIPRW down &> /dev/null
	ifconfig $ETH:2 $VIPRO down &> /dev/null
	exit 1
fi

# is in cluster ?
RDY=`mysql --force -h $MYSQLHOST -P $MYSQLPORT -u $MYSQLUSER -p$MYSQLPASS -B -N -e "SHOW STATUS WHERE Variable_name = 'wsrep_ready';" | awk '{ print $2 }'`
if [ $RDY = "ON" ]; then
	# is synced ?
	SYNC=`mysql --force -h $MYSQLHOST -P $MYSQLPORT -u $MYSQLUSER -p$MYSQLPASS -B -N -e "SHOW STATUS WHERE Variable_name = 'wsrep_local_state_comment';" | awk '{print $2}'`
	if [ $SYNC = "Synced" ]; then
		# SYNCED
		vip
		exit 0
	else
		# NOT SYNCED
		ifconfig $ETH:1 $VIPRW down &> /dev/null
		ifconfig $ETH:2 $VIPRO down &> /dev/null
		exit 1
	fi
else
	# NOT IN CLUSTER
	ifconfig $ETH:1 $VIPRW down &> /dev/null
	ifconfig $ETH:2 $VIPRO down &> /dev/null
	exit 1
fi

exit 0
