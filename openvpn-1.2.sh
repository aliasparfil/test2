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


ipserver() {					#	Interrogation user type utilisation et récupération de l'IP correspondante
	######## IP PUBLIQUE ########
	wget -q -O ip.tmp whatismyip.org
	IP_PUBLIC=$(cat ip.tmp)
	rm ip.tmp
	#############################

	######## IP PRIVEE ########
	IP_PRIVEE=$(ip addr list eth0 |grep "inet " |cut -d' ' -f6|cut -d/ -f1)
	###########################y
	VALID="null"
	
	while :
		do
			echo "Mode LAN ou WAN ? [W/L]"
			read MODE
			if [ $MODE == "W" ]
				then
				VALID="WAN"
				break
			elif [ $MODE == "w" ]
				then
				VALID="WAN"
				break
			elif [ $MODE == "WAN" ]
				then
				VALID="WAN"
				break
			elif [ $MODE == "L" ]
				then
				VALID="LAN"
				break
			elif [ $MODE == "LAN" ]
				then
				VALID="LAN"
				break
			elif [ $MODE == "l" ]
				then
				VALID="LAN"
				break
			fi		
	done
		if [ $VALID == "WAN" ]
			then
			IP_SERVER=$IP_PUBLIC
		elif [ $VALID == "LAN" ]
			then
			IP_SERVER=$IP_PRIVEE
		fi
}

ipvpn() {						#	Intérrogation user IP réseau VPN
	echo "IP réseau VPN désiré ($MASK):"
	read IP
	while :
			do
				echo "IP réseaux entrée : \"$IP $MASK\". Confirmer ? [Y/n]"
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

port() {						#	Intérrogation user port VPN
	echo "Port du serveur (différent de $PORT):"
	read P
	while :
			do
				echo "Port entré : \"$P\". Confirmer ? [Y/n]"
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

vars() {						#	Charge les variables nécessaires à la création de serveurs et clients
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

confserver() {					#	Génère le fichier de conf serveur
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

installovpn() {					#	Installe OpenVPN et créé les répertoires de base
	apt-get update
	apt-get install -y openvpn
	mkdir /etc/openvpn/easy-rsa
	cp /usr/share/doc/openvpn/examples/easy-rsa/2.0/* /etc/openvpn/easy-rsa/
}

removeovpn() {					#	Supprime ENTIEREMENT OpenVPN
	apt-get remove -y openvpn
	rm -r /etc/openvpn
}

reinstallovpn() {				#   Réinstalle OpenVPN de A à Z
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

buildserver() {					#	Créé les fichiers et certificats du premier serveur
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

newserver() {					#	Créé les fichier des serveurs supplémentaires
	vars
	/etc/openvpn/easy-rsa/pkitool --server $SERVER.$HOSTNAME
	cp /etc/openvpn/easy-rsa/keys/$SERVER.$HOSTNAME.crt /etc/openvpn/easy-rsa/keys/$SERVER.$HOSTNAME.key /etc/openvpn/
	confserver
}

buildclient() {					#	Créé un certificat client et les fichiers nécessaires
	vars	
	#creation des certificats
	/etc/openvpn/easy-rsa/pkitool $CLIENT.$HOSTNAME
	#copie et création des fichiers clients
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

tag() {							#	Créé un fichier tag dans /etc/openvpn pour vérifier qu'il s'agit bien d'une installation fait pas nos soins
	echo "1" >> /etc/openvpn/tag
}

revoke() {						#	Supprime un client
	vars	
	/etc/openvpn/easy-rsa/revoke-full $CLIENT.$HOSTNAME
	rm /etc/openvpn/clientconf/$CLIENT.$HOSTNAME.zip
}

restart() {						#	redémarre le service OpenVPN
	/etc/init.d/openvpn restart
}

verifzip() {					#	Vérification installation de zip et installation si besoin
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

verifovpn() {					#	Vérifie une précédente installation d'OpenVPN
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

reconfovpn() {					#	Reconfiguration OpenVPN (cas où pré-installation correcte)
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
					echo "Client \"$OPTARG\" déjà existant !"
				else
					echo "Creation du client $OPTARG"
					CLIENT=$OPTARG
					addclient
					echo "--------------------------------------------------------------------"
					echo "Client $CLIENT ajouté !"
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
						echo "Suppression annulée"
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
				echo "OpenVPN déjà correctement installé."
				ECHO="Voulez-vous le reconfigurer ?"
				confirm
				if [ $VALID == "YES" ]
					then
					echo "Reconfiguration..."
					reconfovpn
					echo "--------------------------------------------------------------------"
					echo "Reconfiguration terminée !"
				else
					echo "--------------------------------------------------------------------"
					echo "Installation annulée"
				fi
			elif [ $VALID == "ALF" ]	#	Si installe incorrecte, reinstallation
				then
				echo "Installation OpenVPN actuelle incorecte."
				ECHO="Voulez-vous réinstaller OpenVPN ? Il sera ENTIEREMENT supprimer puis reinstaller !"
				confirm
				if [ $VALID == "YES" ]
					then
					echo "Reinstallation..."
					reinstallovpn
					echo "--------------------------------------------------------------------"
					echo "Reinstallation terminée !"
				else
					echo "--------------------------------------------------------------------"
					echo "Installation annulée"
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
					echo "Installation terminée !"
				elif [ $VALID == "NO" ]
					then
					echo "--------------------------------------------------------------------"
					echo "installation annulée."
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
					echo "Nouveau serveur configuré !"
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
				ECHO="Voulez-vous faire une reconfiguration ? !!! Attention, toute configuration actuelle sera écrasée !!!"
				confirm
				if [ $VALID == "YES" ]
					then
					echo "Reconfiguration..."
					reconf
					echo "--------------------------------------------------------------------"
					echo "Reconfiguration terminée !"
				elif [ $VALID == "NO" ]
						then
					echo "--------------------------------------------------------------------"
					echo "Reconfiguration annulée."
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
				ECHO="Êtes-vous certain de vouloir supprimer OpenVPN ? TOUT LES FICHIERS ET SERVICES SERONTS SUPPRIMES ET DESINSTALLES !!!"
				confirm
				if [ $VALID == "YES" ]
					then
					removeovpn
					echo "--------------------------------------------------------------------"
					echo "Suppression terminée."
				else
					echo "--------------------------------------------------------------------"
					echo "Suppression annulée."
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
	echo "	-s [serveur]	:	Ajoute un serveur ! nom serveur doit être différent de \"server\" !"
	echo "	-r		:	Execute la reconfiguration du serveur"
	echo "	-R		:	Désinstalle entièrement le serveur."
fi