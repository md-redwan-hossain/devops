import os
import subprocess
from datetime import datetime

# Configuration
directory_name = "db_backup"
backup_dir = os.path.join(os.environ["HOME"], directory_name)
backup_count = 7

# Ensure the backup directory exists
os.makedirs(backup_dir, exist_ok=True)

# Generate the backup file name with a readable timestamp including milliseconds
timestamp = datetime.now().strftime("%d-%m-%Y_%H-%M-%S-%f")[:-3]  # Trim to milliseconds
backup_file = os.path.join(backup_dir, f"backup_file_{timestamp}.sql")

# Perform the database backup
try:
    subprocess.run(
        ["pg_dumpall", "-U", "postgres", "-f", backup_file],
        check=True,
    )
    print(f"Backup completed: {backup_file}")
except subprocess.CalledProcessError as e:
    print(f"Error during backup: {e}")
    exit(1)

# Remove older backups, keeping only the most recent 7
try:
    # List all files in the backup directory
    files = [
        os.path.join(backup_dir, f)
        for f in os.listdir(backup_dir)
        if os.path.isfile(os.path.join(backup_dir, f))
    ]
    # Sort files by modification time (oldest first)
    files.sort(key=os.path.getmtime)

    # Delete older files if more than `backup_count` exist
    if len(files) > backup_count:
        for file_to_remove in files[:-backup_count]:
            os.remove(file_to_remove)
            print(f"Removed old backup: {file_to_remove}")
except Exception as e:
    print(f"Error during cleanup: {e}")
