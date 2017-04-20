#!/bin/bash

# Copyright 2017 MakeMyTrip (Kunal Aggarwal, Avinash Jain)
#
# This file is part of WebGuard.
#
# WebGuard is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# WebGuard is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with WebGuard.  If not, see <http://www.gnu.org/licenses/>.

INSTALL_LOGFILE=webguard_install.log

logit() 
{
	echo "${*}"
	echo "[${USER}][`date`] - ${*}" >> ${INSTALL_LOGFILE}
}

lognoecho() {
	echo "[${USER}][`date`] - ${*}" >> ${INSTALL_LOGFILE}
}

lognoecho "********************************************"
lognoecho "         STARTING WEBGUARD INSTALLER        "
lognoecho "********************************************"

banner() {

	echo "                                                       "
	echo "                         WELCOME TO                    "
	echo "                    __    ______                     __"
	echo "     _      _____  / /_  / ____/_  ______ __________/ /"
	echo "    | | /| / / _ \/ __ \/ / __/ / / / __ \`/ ___/ __  /"
	echo "    | |/ |/ /  __/ /_/ / /_/ / /_/ / /_/ / /  / /_/ /  "
	echo "    |__/|__/\___/_.___/\____/\__,_/\__,_/_/   \__,_/   "
	echo "							     "
	echo "                          INSTALLER                    "
	echo "                            v1.0                       "
	echo "                                                       "

}

install_web() {
	logit "Starting installation for Web Server"
	logit "Installing System dependencies"
	lognoecho "yum install -y mysql mysql-server mysql-devel openldap-devel git gcc"
	yum install -y mysql mysql-server mysql-devel openldap-devel git gcc >> $INSTALL_LOGFILE 2>&1
	retval=$?
	if [ "$retval" == "0" ]; then
		logit "Starting MySQL Server"
		lognoecho /etc/init.d/mysqld start
		/etc/init.d/mysqld start >> $INSTALL_LOGFILE 2>&1
		logit "Setting up MySQL Database for webGuard"
		lognoecho "mysql -uroot -e \"create database webguard;\""
		mysql -uroot -e "create database webguard;" >> $INSTALL_LOGFILE 2>&1
		lognoecho "mysql -uroot -e \"create user 'webguard'@'localhost' identified by 'webguard';\";"
		mysql -uroot -e "create user 'webguard'@'localhost' identified by 'webguard';" >> $INSTALL_LOGFILE 2>&1
		lognoecho "mysql -uroot -e \"grant all privileges on webguard.* to 'webguard'@'localhost';\""
		mysql -uroot -e "grant all privileges on webguard.* to 'webguard'@'localhost';" >> $INSTALL_LOGFILE 2>&1
		lognoecho "mysql -uroot -e \"flush privileges;\";"
		mysql -uroot -e "flush privileges;" >> $INSTALL_LOGFILE 2>&1

		HOME_DIR=/opt/webguard
		mkdir -p $HOME_DIR
	
		logit "Cloning the Web Server git repository"
		lognoecho "git clone https://github.com/makemytrip/webGuard-Server.git $HOME_DIR/server"
		git clone https://github.com/makemytrip/webGuard-Server.git $HOME_DIR/server >> $INSTALL_LOGFILE 2>&1

		logit "Creating and activating Python Virtual Environment"
		lognoecho "virtualenv $HOME_DIR/env"
		virtualenv $HOME_DIR/env >> $INSTALL_LOGFILE 2>&1
		lognoecho ". $HOME_DIR/env/bin/activate"
		. $HOME_DIR/env/bin/activate >> $INSTALL_LOGFILE 2>&1

		logit "Installing Python dependencies in virtual environment"
		lognoecho "pip install -r $HOME_DIR/server/requirements.txt"
		pip install -r $HOME_DIR/server/requirements.txt >> $INSTALL_LOGFILE 2>&1

		lognoecho "cd $HOME_DIR/server"
		cd $HOME_DIR/server
		cp server/settings.py.sample server/settings.py

		logit "Setting up the database"
		lognoecho "python manage.py migrate"
		python manage.py migrate >> $INSTALL_LOGFILE 2>&1

		ip=`hostname -i`
		logit "Server IP is: $ip"

		lognoecho "sed -i \"s/X.X.X.X/$ip/g\" $HOME_DIR/server/server/settings.py"
		sed -i "s/X.X.X.X/$ip/g" $HOME_DIR/server/server/settings.py

		logit "You'll be now guided through the process of creating a super user to access the admin panel, please fill in the required information"
		lognoecho "python manage.py createsuperuser"
		python manage.py createsuperuser

		logit "Staring the server"
		lognoecho "python manage.py runserver $ip:80"
		python manage.py runserver $ip:80

	else
		logit "Failed installing dependencies, please check $INSTALL_LOGFILE for more details."
	fi
}

install_zap() {
	logit "Starting installation for ZAP Server"
        logit "Installing System dependencies"
        lognoecho "yum install -y git gcc"
	yum install -y git gcc >> $INSTALL_LOGFILE 2>&1
	retval=$?
        if [ "$retval" == "0" ]; then
		HOME_DIR="/opt/zap-server"
		echo -n "Enter Web Server IP [10.0.0.1]: "
		read ip
		echo -n "Enter Port [80]: "
		read port
		if [ "z$ip" == "z" ]; then
  			ip="10.0.0.1"
		fi

		if [ "z$port" == "z" ]; then
		        port="80"
		fi
		logit "Web Server IP provided by user: $ip:$port"
		
		logit "Cloning the Web Server git repository"
                lognoecho "git clone https://github.com/makemytrip/webGuard-ZAP.git $HOME_DIR"
		git clone https://github.com/makemytrip/webGuard-ZAP.git $HOME_DIR >> $INSTALL_LOGFILE 2>&1

		logit "Configuring Scripts"
		lognoecho "sed -i \"s/X.X.X.X/$ip:$port/g\" $HOME_DIR/scripts/register.py"
		sed -i "s/X.X.X.X/$ip:$port/g" $HOME_DIR/scripts/register.py
		lognoecho "sed -i \"s/X.X.X.X/$ip:$port/g\" $HOME_DIR/scripts/unregister.py"
		sed -i "s/X.X.X.X/$ip:$port/g" $HOME_DIR/scripts/unregister.py

		logit "Downloading ZAP"
		ZAP_URL="https://github.com/zaproxy/zaproxy/releases/download/2.5.0/ZAP_2.5.0_Linux.tar.gz"
		lognoecho "wget -c $ZAP_URL -O /tmp/zap.tar.gz"
		wget -c $ZAP_URL -O /tmp/zap.tar.gz

		logit "Unpacking and Moving ZAP into place"
		lognoecho "tar xf /tmp/zap.tar.gz -C $HOME_DIR"
		tar xf /tmp/zap.tar.gz -C $HOME_DIR >> $INSTALL_LOGFILE 2>&1
		lognoecho "mv $HOME_DIR/ZAP* $HOME_DIR/zap"
		mv $HOME_DIR/ZAP* $HOME_DIR/zap >> $INSTALL_LOGFILE 2>&1

		logit "Setting up Python Virtual Environment"
		lognoecho "virtualenv $HOME_DIR/env"
		virtualenv $HOME_DIR/env >> $INSTALL_LOGFILE 2>&1
		lognoecho ". $HOME_DIR/env/bin/activate"
		. $HOME_DIR/env/bin/activate >> $INSTALL_LOGFILE 2>&1
		lognoecho "pip install -r $HOME_DIR/requirements.txt"
		pip install -r $HOME_DIR/requirements.txt >> $INSTALL_LOGFILE 2>&1
		lognoecho "deactivate"
		deactivate >> $INSTALL_LOGFILE 2>&1

		logit "Setting up startup scripts"
		lognoecho "ln -s $HOME_DIR/scripts/zap /etc/init.d/"
		ln -s $HOME_DIR/scripts/zap /etc/init.d/
		lognoecho "ln -s $HOME_DIR/scripts/zap-server /etc/init.d/"
		ln -s $HOME_DIR/scripts/zap-server /etc/init.d/
		lognoecho "chkconfig --add zap"
		chkconfig --add zap
		lognoecho "chkconfig --add zap-server"
		chkconfig --add zap-server

		logit "Starting ZAP and ZAP Server"
		lognoecho "/etc/init.d/zap start"
		/etc/init.d/zap start >> $INSTALL_LOGFILE 2>&1
		lognoecho "/etc/init.d/zap-server start"
		/etc/init.d/zap-server start >> $INSTALL_LOGFILE 2>&1
	else
		logit "Failed installing dependencies, please check $INSTALL_LOGFILE for more details."
	fi
}

banner

while true; do
	echo "Select the type of component to be installed"
	echo "1. Web Server"
	echo "2. ZAP Server"
	read -p "Enter your choice [1-2]: " component

	case $component in 
		[1] ) 	echo ""
			install_web 
			break;;
		[2] )	echo ""
			install_zap
			break;;
		* )	echo -e "\nERROR: Please enter the correct option\n"
	esac
done
