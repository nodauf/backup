prepare_dir(){
	#Remove old local files
	mv $DIR_BACKUP/$1/* $DIR_BACKUP/$1/old
	find $DIR_BACKUP/$1 -mtime +$NB_TO_KEEP -exec rm {} \;

	#Remove old remote files
	cd $DIR_DRIVE
	FILES_A_SUPPRIMER=$(drive ls | grep $1 | grep -v "$(drive ls | head -n $NB_TO_KEEP)")
	
	#Parcourir les fichiers à supprimer pour les supprimer :)
	while read FILE
	do
		#If not empty
		if [[ -x $FILE ]]; then

			#We cut to have only the name without the path
			FILE=$(echo $FILE | cut -d"/" -f 3)
			echo "Y" | drive del $FILE
		fi
	done <<< "$FILES_A_SUPPRIMER"
	
}

#backup_bdd subdirectory_backup
backup_bdd(){
	mysqldump -u root -p$PASSWORD_BDD $2 > $DIR_BACKUP/$1/BDD-$1-$JOUR.sql
}

#backup_files subdirectory_backup Name_of_this_backup Directory_to_backup
backup_files(){
	tar -cf $DIR_BACKUP/$1/FILES-$2-$JOUR.tar.gz $3	
}

#encrypt subdirectory_backup
encrypt(){
	#On rassemble tout
	tar -cvf $DIR_BACKUP/$1.tar.gz $DIR_BACKUP/$1/* --exclude=$DIR_OLD
	openssl aes-256-cbc -e -k $PASSWORD -a -in $DIR_BACKUP/$1.tar.gz  > $DIR_BACKUP/$1-$JOUR.encrypt
	
	#Suppression de l'archive à chiffrer temporaire
	rm $DIR_BACKUP/$1.tar.gz

	sha512sum $DIR_BACKUP/$1-$JOUR.encrypt > $DIR_BACKUP/$1-$JOUR.checksum #Checksum
	tar -cvf $DIR_BACKUP/$1-$JOUR.tar.gz $DIR_BACKUP/$1-$JOUR.encrypt $DIR_BACKUP/$1-$JOUR.checksum	#On rassemble tous les fichiers

	#On supprime tous
	rm $DIR_BACKUP/$1-$JOUR.checksum
	rm $DIR_BACKUP/$1-$JOUR.encrypt
}

#send_drive  folder_to_push_to_drive
#Send the backup in the google drive
send_drive(){
	cp $DIR_BACKUP/$1-$JOUR.tar.gz $DIR_DRIVE/ && rm $DIR_BACKUP/$1-$JOUR.tar.gz
	cd $DIR_DRIVE
	echo Y | drive push $1-$JOUR.tar.gz && rm $DIR_DRIVE/$1-$JOUR.tar.gz	
}
#Import the conf file
source /root/Scripts/Backup/backup.conf

#debug
if [[ $1 == "y" ]]; then
	set -xvp
fi

prepare_dir owncloud
prepare_dir wordpress
prepare_dir gogs

backup_bdd owncloud owncloud
backup_bdd wordpress wordpress_bdd
backup_bdd gogs gogs

backup_files owncloud owncloud-config /usr/share/nginx/www/owncloud
backup_files owncloud owncloud-data /home/owncloud
backup_files wordpress wordpress /usr/share/nginx/www/wordpress
backup_files gogs gogs-data /home/gogs
backup_files gogs gogs-config /opt/gogs/conf

encrypt owncloud
encrypt wordpress
encrypt gogs

send_drive owncloud
send_drive wordpress
send_drive gogs
