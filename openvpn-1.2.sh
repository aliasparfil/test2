#!/bin/bash

####################################################
#                INSTALLATEUR  OPENVPN             #
####################################################

SERVER='server'
CLIENT='client'
HOSTNAME=$(hostname)
DEV='tap'
PROTO='tcp'
PORT='1194'



ipvpn() {						#	Int�rrogation user IP r�seau VPN
	echo "IP r�seau VPN d�sir� ($MASK):"
	read IP
	while :
			do
				echo "IP r�seaux entr�e : \"$IP $MASK\". Confirmer ? [Y/n]"
				read CONF
				if [ $CONF == "Y" ]
					then
					VALID="YES"
					break
				elif [ $CONF == "y" ]
					then
					VALID="YES"
					break
				elif [ $CONF == "N" ]
					then
					VALID="NO"
					break
				elif [ $CONF == "n" ]
					then
					VALID="NO"
					break
				fi		
	done
	if [ $VALID == "YES" ]
		then
		IP_VPN=$IP
	elif [ $VALID == "NO" ]
		then
		ipvpn
	fi
}

port() {						#	Int�rrogation user port VPN
	echo "Port du serveur (diff�rent de $PORT):"
	read P
	while :
			do
				echo "Port entr� : \"$P\". Confirmer ? [Y/n]"
				read CONF
				if [ $CONF == "Y" ]
					then
					VALID="YES"
					break
				elif [ $CONF == "y" ]
					then
					VALID="YES"
					break
				elif [ $CONF == "N" ]
					then
					VALID="NO"
					break
				elif [ $CONF == "n" ]
					then
					VALID="NO"
					break
				fi		
	done
	if [ $VALID == "YES" ]
		then
		PORT=$P
	elif [ $VALID == "NO" ]
		then
		port
	fi
}

vars() {						#	Charge les variables n�cessaires � la cr�ation de serveurs et clients
	#	easy-rsa parameter settings
	export EASY_RSA="/etc/openvpn/easy-rsa"
	export OPENSSL="openssl"
	export PKCS11TOOL="pkcs11-tool"
	export GREP="grep"
	export KEY_CONFIG=`$EASY_RSA/whichopensslcnf $EASY_RSA`
	export KEY_DIR="/etc/openvpn/easy-rsa/keys"
	echo NOTE: If you run ./clean-all, I will be doing a rm -rf on $KEY_DIR
	export PKCS11_MODULE_PATH="dummy"
	export PKCS11_PIN="dummy"
	export KEY_SIZE=1024
	export CA_EXPIRE=3650
	export KEY_EXPIRE=180
	export KEY_COUNTRY="FR"
	export KEY_PROVINCE="France"
	export KEY_CITY="Paris"
	export KEY_ORG="$HOSTNAME"
	export KEY_EMAIL="christian@chuinard.fr"
}

confserver() {					#	G�n�re le fichier de conf serveur
	echo "	# Serveur $PROTO/$PORT
	mode server
	proto $PROTO
	port $PORT
	dev $DEV
	
	# Cles et certificats
	ca ca.crt
	cert $SERVER.$HOSTNAME.crt
	key $SERVER.$HOSTNAME.key
	dh dh1024.pem
	tls-auth ta.key 0
	cipher AES-256-CBC
	duplicate-cn
	
	# Reseau
	server $IP_VPN $MASK
	keepalive 10 120
	
	# Securite
	user nobody
	group nogroup
	chroot /etc/openvpn/jail
	persist-key
	persist-tun
	comp-lzo
	
	# Log
	verb 3
	mute 20
	status openvpn-status.log
	log-append /var/log/openvpn.log
	" >> /etc/openvpn/$SERVER.conf
}

installovpn() {					#	Installe OpenVPN et cr�� les r�pertoires de base
	apt-get update
	apt-get install -y openvpn
	mkdir /etc/openvpn/easy-rsa
	cp /usr/share/doc/openvpn/examples/easy-rsa/2.0/* /etc/openvpn/easy-rsa/
}

removeovpn() {					#	Supprime ENTIEREMENT OpenVPN
	apt-get remove -y openvpn
	rm -r /etc/openvpn
}

reinstallovpn() {				#   R�installe OpenVPN de A � Z
	removeovpn
	installationovpn
}

cleanall() {					#	refait un dossier /etc/openvpn propre
	/etc/openvpn/easy-rsa/clean-all
	rm -r /etc/openvpn
	mkdir /etc/openvpn
	mkdir /etc/openvpn/easy-rsa
	cp /usr/share/doc/openvpn/examples/easy-rsa/2.0/* /etc/openvpn/easy-rsa/
}

buildserver() {					#	Cr�� les fichiers et certificats du premier serveur
	vars
	mkdir /etc/openvpn/jail
	mkdir /etc/openvpn/clientconf
	
	/etc/openvpn/easy-rsa/clean-all
	/etc/openvpn/easy-rsa/build-dh
	/etc/openvpn/easy-rsa/pkitool --initca
	/etc/openvpn/easy-rsa/pkitool --server $SERVER.$HOSTNAME
	openvpn --genkey --secret /etc/openvpn/easy-rsa/keys/ta.key
	cp /etc/openvpn/easy-rsa/keys/dh1024.pem /etc/openvpn/easy-rsa/keys/ca.crt /etc/openvpn/easy-rsa/keys/ta.key /etc/openvpn/easy-rsa/keys/$SERVER.$HOSTNAME.crt /etc/openvpn/easy-rsa/keys/$SERVER.$HOSTNAME.key /etc/openvpn/
	confserver
}

newserver() {					#	Cr�� les fichier des serveurs suppl�mentaires
	vars
	/etc/openvpn/easy-rsa/pkitool --server $SERVER.$HOSTNAME
	cp /etc/openvpn/easy-rsa/keys/$SERVER.$HOSTNAME.crt /etc/openvpn/easy-rsa/keys/$SERVER.$HOSTNAME.key /etc/openvpn/
	confserver
}

buildclient() {					#	Cr�� un certificat client et les fichiers n�cessaires
	vars	
	#creation des certificats
	/etc/openvpn/easy-rsa/pkitool $CLIENT.$HOSTNAME
	#copie et cr�ation des fichiers clients
	mkdir /etc/openvpn/clientconf/$CLIENT.$HOSTNAME/
	cp /etc/openvpn/easy-rsa/keys/$CLIENT.$HOSTNAME.crt /etc/openvpn/clientconf/$CLIENT.$HOSTNAME/
	cp /etc/openvpn/easy-rsa/keys/$CLIENT.$HOSTNAME.key /etc/openvpn/clientconf/$CLIENT.$HOSTNAME/
	cp /etc/openvpn/easy-rsa/keys/ca.crt /etc/openvpn/clientconf/$CLIENT.$HOSTNAME/
	cp /etc/openvpn/easy-rsa/keys/ta.key /etc/openvpn/clientconf/$CLIENT.$HOSTNAME/
	chmod 777 /etc/openvpn/clientconf/
	echo "	# $CLIENT.$HOSTNAME
	client
	dev $DEV
	proto $PROTO-client
	remote $IP_SERVER $PORT
	resolv-retry infinite
	cipher AES-256-CBC
	# Cles
	ca ./$CLIENT.$HOSTNAME/ca.crt
	cert ./$CLIENT.$HOSTNAME/$CLIENT.$HOSTNAME.crt
	key ./$CLIENT.$HOSTNAME/$CLIENT.$HOSTNAME.key
	tls-auth ./$CLIENT.$HOSTNAME/ta.key 1
	# Securite
	nobind
	persist-key
	persist-tun
	comp-lzo
	verb 3" >> /etc/openvpn/clientconf/$CLIENT.$HOSTNAME.ovpn
	cp /etc/openvpn/clientconf/$CLIENT.$HOSTNAME.ovpn /etc/openvpn/clientconf/$CLIENT.$HOSTNAME.conf
	#creation du zip
	cd /etc/openvpn/clientconf/
	zip -r $CLIENT.$HOSTNAME.zip *
	rm -r /etc/openvpn/clientconf/$CLIENT.$HOSTNAME
	rm /etc/openvpn/clientconf/$CLIENT.$HOSTNAME.conf /etc/openvpn/clientconf/$CLIENT.$HOSTNAME.ovpn
}

tag() {							#	Cr�� un fichier tag dans /etc/openvpn pour v�rifier qu'il s'agit bien d'une installation fait pas nos soins
	echo "1" >> /etc/openvpn/tag
}

revoke() {						#	Supprime un client
	vars	
	/etc/openvpn/easy-rsa/revoke-full $CLIENT.$HOSTNAME
	rm /etc/openvpn/clientconf/$CLIENT.$HOSTNAME.zip
}

restart() {						#	red�marre le service OpenVPN
	/etc/init.d/openvpn restart
}

verifzip() {					#	V�rification installation de zip et installation si besoin
	if test -f  /usr/bin/zip
		then
		if test -f /usr/bin/unzip
			then
			cat /dev/null
		else
			apt-get update
			apt-get install -y zip unzip
		fi
	else
		apt-get update
		apt-get install -y zip unzip
	fi
}

confirm() {						#	Formulaire de confirmation Y/n
	VALID="null"
	while :
		do
			echo "$ECHO [Y/n]"
			read RECONFIG
			if [ $RECONFIG == "Y" ]
				then
				VALID="YES"
				break
			elif [ $RECONFIG == "y" ]
				then
				VALID="YES"
				break
			elif [ $RECONFIG == "N" ]
				then
				break
			elif [ $RECONFIG == "n" ]
				then
				break
			fi		
	done
}

verifovpn() {					#	V�rifie une pr�c�dente installation d'OpenVPN
	INSTALL="null"
	TAG="null"
	VALID="null"
	if test -d /etc/openvpn
		then
		INSTALL="YES"
		if test -f /etc/openvpn/tag
			then
			TAG="YES"
		fi
	fi
	if [ $INSTALL == "YES" ]
		then
		VALID="ALF"
		if [ $TAG == "YES" ]
			then
			VALID="FULL"
		fi
	else
		VALID="NO"
	fi
}

addserver() {					#	Ajout de serveur
	ipvpn
	port
	newserver
	restart
}

addclient() {					#	Ajout de client
	verifzip
	ipserver
	buildclient
	restart
}

installationovpn() {			#	Installation d'OpenVPN si pas d'installation deja presente
	verifzip
	ipserver
	ipvpn
	installovpn
	buildserver
	tag
	buildclient
	restart
}

reconfovpn() {					#	Reconfiguration OpenVPN (cas o� pr�-installation correcte)
	verifzip
	ipserver
	ipvpn
	cleanall
	buildserver
	tag
	buildclient
	restart
}

if [ $1 ]
	############## OPTIONS ##############
	then 
	while getopts c:d:is:rR option
		do
		case $option in
			##########################
			c)	#	Ajout de client
			verifovpn
			if [ $VALID != "FULL" ]
				then
				echo "Veuillez installer et configurer OpenVPN !"
			else
				if test -f /etc/openvpn/clientconf/$OPTARG.*
					then
					echo "Client \"$OPTARG\" d�j� existant !"
				else
					echo "Creation du client $OPTARG"
					CLIENT=$OPTARG
					addclient
					echo "--------------------------------------------------------------------"
					echo "Client $CLIENT ajout� !"
				fi
			fi
			;;
			##########################
			d)	#	Suppression de client
			verifovpn
			if [ $VALID != "FULL" ]
				then
				echo "Veuillez installer et configurer OpenVPN !"
			else
				if test -f  /etc/openvpn/clientconf/$OPTARG.$HOSTNAME.zip
					then
					ECHO="Confirmer suppression client \"$OPTARG\" ?"
					confirm
					if [ $VALID == "YES" ]
						then
						echo "Suppression du client $OPTARG"
						CLIENT=$OPTARG
						revoke
					else
						echo "--------------------------------------------------------------------"
						echo "Suppression annul�e"
					fi
				else
					echo "--------------------------------------------------------------------"
					echo "client inexistant !"
				fi
			fi
			;;
			##########################
			i)	#	Installation d'OVPN
			verifovpn
			if [ $VALID == "FULL" ]	#	Si installe correcte, reconfiguration
				then
				echo "OpenVPN d�j� correctement install�."
				ECHO="Voulez-vous le reconfigurer ?"
				confirm
				if [ $VALID == "YES" ]
					then
					echo "Reconfiguration..."
					reconfovpn
					echo "--------------------------------------------------------------------"
					echo "Reconfiguration termin�e !"
				else
					echo "--------------------------------------------------------------------"
					echo "Installation annul�e"
				fi
			elif [ $VALID == "ALF" ]	#	Si installe incorrecte, reinstallation
				then
				echo "Installation OpenVPN actuelle incorecte."
				ECHO="Voulez-vous r�installer OpenVPN ? Il sera ENTIEREMENT supprimer puis reinstaller !"
				confirm
				if [ $VALID == "YES" ]
					then
					echo "Reinstallation..."
					reinstallovpn
					echo "--------------------------------------------------------------------"
					echo "Reinstallation termin�e !"
				else
					echo "--------------------------------------------------------------------"
					echo "Installation annul�e"
				fi
			else	#	Si pas d'installation, installation
				echo "Openvpn inexistant."
				ECHO="Voulez-vous l'installer ?"
				confirm
				if [ $VALID == "YES" ]
					then
					echo "Installation..."
					installationovpn
					echo "--------------------------------------------------------------------"
					echo "Installation termin�e !"
				elif [ $VALID == "NO" ]
					then
					echo "--------------------------------------------------------------------"
					echo "installation annul�e."
				fi
			fi
			;;
			##########################
			s)	#	Ajout de serveur
			verifovpn
			if [ $VALID == "FULL" ]
				then
				if test -f  /etc/openvpn/$OPTARG.conf
					then
					echo "Serveur deja existant."
				else
					SERVER=$OPTARG
					addserver
					echo "--------------------------------------------------------------------"
					echo "Nouveau serveur configur� !"
				fi
			else
				echo "Veuillez installer et configurer OpenVPN !"
			fi
			;;
			##########################
			r)	#	Reconfiguration OVPN
			verifovpn
			if [ $VALID != "NO" ]
				then
				ECHO="Voulez-vous faire une reconfiguration ? !!! Attention, toute configuration actuelle sera �cras�e !!!"
				confirm
				if [ $VALID == "YES" ]
					then
					echo "Reconfiguration..."
					reconf
					echo "--------------------------------------------------------------------"
					echo "Reconfiguration termin�e !"
				elif [ $VALID == "NO" ]
						then
					echo "--------------------------------------------------------------------"
					echo "Reconfiguration annul�e."
				fi
			else
				echo "Veuillez d'abord installer OpenVPN."
			fi
			;;
			##########################
			R)	#	Suppression complete OVPN
			verifovpn
			if [ $VALID != "NO" ]
				then
				ECHO="�tes-vous certain de vouloir supprimer OpenVPN ? TOUT LES FICHIERS ET SERVICES SERONTS SUPPRIMES ET DESINSTALLES !!!"
				confirm
				if [ $VALID == "YES" ]
					then
					removeovpn
					echo "--------------------------------------------------------------------"
					echo "Suppression termin�e."
				else
					echo "--------------------------------------------------------------------"
					echo "Suppression annul�e."
				fi
			else
				echo "OpenVPN inexistant"
			fi
			;;
			##########################
		esac
	done
else
	echo "SCRIPT D'INSTALLATION OPENVPN VERSION 1.2"
	echo ""
	echo "UTILISATION [root]:"
	echo "	# bash ./openvpn-1.2.sh [OPTION]"
	echo ""
	echo "OPTIONS :"
	echo "	-c [client]	:	Ajoute un client"
	echo "	-d [client]	:	Supprime un client"
	echo "	-i		:	Execute l'installateur"
	echo "	-s [serveur]	:	Ajoute un serveur ! nom serveur doit �tre diff�rent de \"server\" !"
	echo "	-r		:	Execute la reconfiguration du serveur"
	echo "	-R		:	D�sinstalle enti�rement le serveur."
fi