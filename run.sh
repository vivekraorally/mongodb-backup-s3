#!/bin/bash

echo "=> Creating backup script"
rm -f /backup.sh
cat <<EOF >> /backup.sh
#!/bin/bash
# 1 - MONGODB_HOST
# 1 - MONGODB_PORT
# 1 - MONGODB_USER
# 1 - MONGODB_PASS
# 1 - BUCKET
# 1 - BACKUP_FOLDER
# 1 - MONGODB_DB
# 1 - MONGODB_COLLECTION
# 1 - EXTRA_OPTS

OPTIND=1         # Reset in case getopts has been used previously in the shell.
while getopts "h:u:p:b:f:d:c:e" opt; do
    case "$opt" in
    # required args
    h)  MONGODB_HOST=$OPTARG
		;;
    u)  MONGODB_USER=$OPTARG
        ;;
    p)  MONGODB_PASS=$OPTARG
        ;;
    b)  BUCKET=$OPTARG
        ;;
    f)  BACKUP_FOLDER=$OPTARG
        ;;
    d)  MONGODB_DB=$OPTARG
        ;;
    c)  MONGODB_COLLECTIONS=$OPTARG
        ;;
    e)  EXTRA_OPTS=$OPTARG
        ;;
    *)
        echo "Unrecognized option: ${opt}" >&2
        exit 1
        ;;
    esac
done

if [ -z "$MONGODB_HOST" ];then
    #helptext
    #tildes
    echo "Backup failed - host is missing"
    exit 1
fi

if [ -z "$MONGODB_USER" ];then
    #helptext
    #tildes
    echo "Backup failed - user is missing"
    exit 1
fi

if [ -z "$MONGODB_PASS" ];then
    #helptext
    #tildes
    echo "Backup failed - password is missing"
    exit 1
fi

if [ -z "$BUCKET" ];then
    #helptext
    #tildes
    echo "Backup failed - s3 bucket is missing"
    exit 1
fi

if [ -z "$BACKUP_FOLDER" ];then
    #helptext
    #tildes
    echo "Backup failed - s3 backup folder is missing"
    exit 1
fi

if [ -z "$MONGODB_DB" ];then
    #helptext
    #tildes
    echo "Backup failed - db name is missing"
    exit 1
fi

if [ -z "$EXTRA_OPTS" ];then
    #helptext
    #tildes
    echo "No extra options specified"
fi

MONGODB_HOST=${MONGODB_PORT_27017_TCP_ADDR:-${MONGODB_HOST}}
MONGODB_HOST=${MONGODB_PORT_1_27017_TCP_ADDR:-${MONGODB_HOST}}
MONGODB_PORT=${MONGODB_PORT_27017_TCP_PORT:-${MONGODB_PORT}}
MONGODB_PORT=${MONGODB_PORT_1_27017_TCP_PORT:-${MONGODB_PORT}}
MONGODB_USER=${MONGODB_USER:-${MONGODB_ENV_MONGODB_USER}}
MONGODB_PASS=${MONGODB_PASS:-${MONGODB_ENV_MONGODB_PASS}}

S3PATH="s3://$BUCKET/$BACKUP_FOLDER"

[[ ( -z "${MONGODB_USER}" ) && ( -n "${MONGODB_PASS}" ) ]] && MONGODB_USER='admin'

[[ ( -n "${MONGODB_USER}" ) ]] && USER_STR=" --username ${MONGODB_USER}"
[[ ( -n "${MONGODB_PASS}" ) ]] && PASS_STR=" --password '${MONGODB_PASS}'"
[[ ( -n "${MONGODB_DB}" ) ]] && DB_STR=" --db ${MONGODB_DB}"

TIMESTAMP=\`/bin/date +"%Y%m%dT%H%M%S"\`
BACKUP_NAME=\${TIMESTAMP}.dump.gz
S3BACKUP=${S3PATH}\${BACKUP_NAME}
S3LATEST=${S3PATH}latest.dump.gz
echo "=> Backup started"
if [ -z "$MONGODB_COLLECTIONS" ];then
    #helptext
    #tildes
    echo "Collection not specified...performing full db backup (Unless you excluded collections in EXTRA_OPTS)"
else
    for COLLECTION in $(echo $MONGODB_COLLECTIONS | sed "s/,/ /g")
    do
        BACKUP_NAME="$COLLECTION_$BACKUP_NAME"
        mongodump --host ${MONGODB_HOST} --port ${MONGODB_PORT} ${USER_STR}${PASS_STR}${DB_STR} --collection ${COLLECTION} --archive=\${BACKUP_NAME} --gzip ${EXTRA_OPTS}
    done
fi
if mongodump --host ${MONGODB_HOST} --port ${MONGODB_PORT} ${USER_STR}${PASS_STR}${DB_STR} --archive=\${BACKUP_NAME} --gzip ${EXTRA_OPTS} && aws s3 cp \${BACKUP_NAME} \${S3BACKUP} && aws s3 cp \${S3BACKUP} \${S3LATEST} && rm \${BACKUP_NAME} ;then
    echo "   > Backup succeeded"
else
    echo "   > Backup failed"
fi
echo "=> Done"
EOF
chmod +x /backup.sh
echo "=> Backup script created"

echo "=> Creating restore script"
rm -f /restore.sh
cat <<EOF >> /restore.sh
#!/bin/bash
if [[( -n "\${1}" )]];then
    RESTORE_ME=\${1}.dump.gz
else
    RESTORE_ME=latest.dump.gz
fi
S3RESTORE=${S3PATH}\${RESTORE_ME}
echo "=> Restore database from \${RESTORE_ME}"
if aws s3 cp \${S3RESTORE} \${RESTORE_ME} && mongorestore --host ${MONGODB_HOST} --port ${MONGODB_PORT} ${USER_STR}${PASS_STR}${DB_STR} --drop ${EXTRA_OPTS} --archive=\${RESTORE_ME} --gzip && rm \${RESTORE_ME}; then
    echo "   Restore succeeded"
else
    echo "   Restore failed"
fi
echo "=> Done"
EOF
chmod +x /restore.sh
echo "=> Restore script created"

echo "=> Creating list script"
rm -f /listbackups.sh
cat <<EOF >> /listbackups.sh
#!/bin/bash
aws s3 ls ${S3PATH}
EOF
chmod +x /listbackups.sh
echo "=> List script created"

ln -s /restore.sh /usr/bin/restore
ln -s /backup.sh /usr/bin/backup
ln -s /listbackups.sh /usr/bin/listbackups

touch /mongo_backup.log

while :
do
	sleep 10
done
