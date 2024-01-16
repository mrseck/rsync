#!/bin/bash

# Configurable variables
SOURCE_DIR="/var/lib/pgsql/15/data/log"
DEST_HOST="username@ipDestinationHost"
DEST_DIR="/home/sismael"
BACKUP_NAME=$(date +%Y%m%d_%H%M)
KEEP_BACKUPS=7  # Number of backups to keep
MAIL_TO="xx@yy.com"
MAIL_FROM="yy@zz.com"
LOG_FILE="/var/log/backup_script.log"

# Create a temporary directory for incremental backup
TEMP_DIR=$(mktemp -d)

# Perform the first backup (full copy) if the destination doesn't exist
if [[ ! -d "$DEST_DIR" ]]; then
    rsync -avz --delete "$SOURCE_DIR" "$DEST_HOST:$DEST_DIR" >> "$LOG_FILE" 2>&1
else
    # Create a hard link to the previous backup in the temporary directory
    PREV_BACKUP=$(ls -td "$DEST_DIR"/* | head -n 1)
    ln -f "$PREV_BACKUP" "$TEMP_DIR/previous_backup"

    # Perform incremental backup using hard links
    rsync -avz --link-dest="$TEMP_DIR/previous_backup" --delete "$SOURCE_DIR" "$DEST_HOST:$DEST_DIR/$BACKUP_NAME" >> "$LOG_FILE" 2>&1
fi

# Rotate backups if necessary
if [[ $(ls -1 "$DEST_DIR" | wc -l) -gt $KEEP_BACKUPS ]]; then
    rm -rf "$(ls -td "$DEST_DIR"/* | tail -n +$((KEEP_BACKUPS + 1)))" >> "$LOG_FILE" 2>&1
fi

# Clean up temporary directory
rm -rf "$TEMP_DIR"

# Send email notification based on backup status
if [[ $? -eq 0 ]]; then
    echo "Backup completed successfully!" | mail -s "Backup Report: $BACKUP_NAME" -r "$MAIL_FROM" "$MAIL_TO"
else
    echo "Backup failed!" | mail -s "Backup Alert: $BACKUP_NAME" -r "$MAIL_FROM" "$MAIL_TO"
fi
