# SQL Backup Tool for Linux
A tool for automating SQL database backups and sending email notifications with attachments.

![Auto Backup SQL](https://itsmeit.co/wp-content/uploads/2025/01/auto-back-up-sql.png)

## Requirements:
- **Linux** or Linux-based distributions
- **Mail service**: Sendmail, Exim4, or Postfix (required if sending email attachments)

## Installation:

### Manual Installation
1. Download the `bk-sqls` file.
2. Customize the configuration (e.g., backup path, email settings, etc.).
3. Upload the `bk-sqls` file to `/etc/cron.daily`.
4. Set execute permission: `sudo chmod +x /etc/cron.daily/bk-sqls`

### Automated Installation
1. Download and extract the ZIP file.
2. Navigate to the extracted directory and set execute permission for the installer:
   `sudo chmod +x install.sh`
3. Run the installer with sudo: `sudo ./install.sh`
4. Follow the on-screen instructions in the terminal to complete the setup.

## Test Script
- After completing the setup, you can test the script by running the following command in the terminal:
  `sudo /etc/cron.daily/bk-sqls`

## Database Restoration
- The backup file is in the *.sql.gz format. You need to extract it first, then import it into the database to restore the data.
  `gunzip backup.sql.gz`

## Notes:
- Modify the sender and recipient email settings as needed.
- The server must have a working **sendmail** service and an active **cronjob**.
- SQL backups will be automatically created on a daily, weekly, or monthly basis in the default directory: `/var/backups/db`.

---
## Contact support: 
- Email: buivanloi.2010@gmail.com
- Facebook: https://facebook.com/itsmeit.co
- Website: https://itsmeit.co/
