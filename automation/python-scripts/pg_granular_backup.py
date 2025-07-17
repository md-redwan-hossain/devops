import os
import subprocess
from datetime import datetime

# Configuration
base_backup_dir = os.path.join(os.environ["HOME"], "db_backup")
backup_count = 20
db_user = "postgres"
pg_host = "localhost"
pg_port = "5432"

# Create a timestamped folder
timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S-%f")[:-3]
backup_dir = os.path.join(base_backup_dir, timestamp)
os.makedirs(backup_dir, exist_ok=True)
print(f"Created backup folder: {backup_dir}")

# Fetch all non-template databases
databases = subprocess.check_output([
    "psql", "-U", db_user, "-h", pg_host, "-p", pg_port,
    "-Atc", "SELECT datname FROM pg_database WHERE datistemplate=false;"
], text=True).splitlines()

# Dump each database
for db in databases:
    dump_file = os.path.join(backup_dir, f"{db}.dump")
    print(f"Backing up DB '{db}' → {dump_file}")
    try:
        subprocess.run([
            "pg_dump", "-U", db_user, "-h", pg_host, "-p", pg_port,
            "-F", "c", "-f", dump_file, db
        ], check=True)
        print(f"✔ {db} backed up successfully")
    except subprocess.CalledProcessError as e:
        print(f"✗ Error backing up {db}: {e}")

# Dump global objects (roles, tablespaces, etc.)
globals_file = os.path.join(backup_dir, "globals.sql")
print(f"Backing up globals → {globals_file}")
try:
    subprocess.run([
        "pg_dumpall", "-U", db_user, "-h", pg_host, "-p", pg_port,
        "--globals-only", "-f", globals_file
    ], check=True)
    print("✔ Globals backed up successfully")
except subprocess.CalledProcessError as e:
    print(f"✗ Error backing up globals: {e}")

# Cleanup: keep only the latest 'backup_count' backup folders
all_dirs = sorted(
    [os.path.join(base_backup_dir, d) for d in os.listdir(base_backup_dir)
     if os.path.isdir(os.path.join(base_backup_dir, d))],
    key=os.path.getmtime
)
if len(all_dirs) > backup_count:
    for old in all_dirs[:-backup_count]:
        subprocess.run(["rm", "-rf", old])
        print(f"🗑️ Removed old backup folder: {old}")
