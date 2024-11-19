sudo cp -r . /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable pg_backup.timer
sudo systemctl start pg_backup.timer
