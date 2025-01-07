#!/bin/bash

# Hàm kiểm tra định dạng email hợp lệ
is_valid_email() {
  local email="$1"
  echo "$email" | grep -E -q "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
  if [ $? -eq 0 ]; then
    return 0 # Đúng định dạng email
  else
    return 1 # Sai định dạng email
  fi
}

# Bắt đầu cấu hình
echo "Step 1: Backup Storage Path (default: /var/backups/db)"
while true; do
  read -p "Press Enter to use default, or enter custom storage path: " BACKUP_DIR
  BACKUP_DIR=$(echo "$BACKUP_DIR" | xargs)  # Loại bỏ khoảng trắng thừa
  BACKUP_DIR=${BACKUP_DIR:-/var/backups/db} # Sử dụng mặc định nếu không nhập gì

  # Kiểm tra xem đường dẫn có phải là một thư mục hợp lệ không
  if [ -d "$BACKUP_DIR" ] || mkdir -p "$BACKUP_DIR"; then
    break
  else
    echo "Invalid directory. Please enter a valid directory path."
  fi
done

echo "Backup directory is ready at: $BACKUP_DIR"

# Kiểm tra các công cụ gửi mail phổ biến
echo ""
echo "Step 2: Checking for Mail Services"

MAIL_SERVICE=""

if command -v sendmail >/dev/null 2>&1; then
  MAIL_SERVICE="sendmail"
  echo "Sendmail service detected. Do you want to configure email notifications for backup?"
elif command -v exim >/dev/null 2>&1; then
  MAIL_SERVICE="exim"
  echo "Exim service detected."
elif command -v postfix >/dev/null 2>&1; then
  MAIL_SERVICE="postfix"
  echo "Postfix service detected."
else
  echo "No mail service detected (sendmail, exim, postfix). Email configuration skipped."
  exit 1
fi

# Hỏi người dùng có muốn cấu hình gửi mail với tùy chọn y/d/n
if [ -n "$MAIL_SERVICE" ]; then
  while true; do
    echo "d: Default - send mail without attachments"
    echo "n: No - do not send email"
    echo "y: Yes - send mail with attachments"

    read -p "Please select an option (d/y/n): " SEND_EMAIL
    SEND_EMAIL=$(echo "$SEND_EMAIL" | xargs) # Loại bỏ khoảng trắng thừa

    if [ "$SEND_EMAIL" = "y" ] || [ "$SEND_EMAIL" = "Y" ]; then
      EMAIL_OPTION="attachments"
      break
    elif [ "$SEND_EMAIL" = "d" ] || [ "$SEND_EMAIL" = "D" ]; then
      EMAIL_OPTION="no_attachments"
      break
    elif [ "$SEND_EMAIL" = "n" ] || [ "$SEND_EMAIL" = "N" ]; then
      EMAIL_OPTION="no_email"
      break
    else
      echo "Invalid input. Please enter 'y', 'd', or 'n'."
    fi
  done

  # Nếu người dùng chọn gửi email, yêu cầu cấu hình thêm
  if [ "$EMAIL_OPTION" = "attachments" ] || [ "$EMAIL_OPTION" = "no_attachments" ]; then
    echo ""
    echo "Step 3: Configure Email Settings"
    read -p "Enter the recipient's email address: " EMAIL_TO
    EMAIL_TO=$(echo "$EMAIL_TO" | xargs)
    while ! is_valid_email "$EMAIL_TO"; do
      echo "Invalid email format. Please enter a valid recipient's email address."
      read -p "Enter the recipient's email address: " EMAIL_TO
      EMAIL_TO=$(echo "$EMAIL_TO" | xargs)
    done

    read -p "Enter the sender's name (default: Admin): " SENDER_NAME
    SENDER_NAME=$(echo "$SENDER_NAME" | xargs)
    SENDER_NAME=${SENDER_NAME:-Admin}

    echo "Email configuration completed:"
    echo ""
    echo "  Sender Name: $SENDER_NAME"
    echo "  Recipient: $EMAIL_TO"
  else
    echo ""
    echo "Step 3: Configure Email Settings"
    echo "Email configuration skipped."
    EMAIL_TO=""
    SENDER_NAME=""
  fi
else
  echo "No mail service detected (sendmail, exim, postfix). Email configuration skipped."
  EMAIL_TO=""
  SENDER_NAME=""
fi

echo ""
echo "Step 4: Configure Backup Script in cron.daily"
# Cấu hình script backup trong cron.daily
CRON_DIR="/etc/cron.daily/"
CRON_FILE="${CRON_DIR}bk-sqls"
sudo cp ./bk-sqls "$CRON_DIR"
sudo chmod +x "$CRON_FILE"
echo "Backup script copied to $CRON_FILE and set as executable."

# Cập nhật cấu hình trong file script
echo ""
echo "Step 5: Configuring Backup Script... "
sed -i "s|^BACKUP_DIR=.*|BACKUP_DIR=\"$BACKUP_DIR\"|" "$CRON_FILE"
sed -i "s|^EMAIL_TO=.*|EMAIL_TO=\"$EMAIL_TO\"|" "$CRON_FILE"
sed -i "s|^SENDER_NAME=.*|SENDER_NAME=\"$SENDER_NAME\"|" "$CRON_FILE"
sed -i "s|^EMAIL_OPTION=.*|EMAIL_OPTION=\"$EMAIL_OPTION\"|" "$CRON_FILE"

# Hoàn tất
echo "Setup completed! All database backups are now scheduled to run daily."
