sudo cp pg_backup.service pg_backup.timer /etc/systemd/system/

sudo sed -i "s/demo_user/$USER/g" ./pg_backup.service /etc/systemd/system/pg_backup.service

sudo systemctl daemon-reload
sudo systemctl enable pg_backup.timer
sudo systemctl start pg_backup.timer
