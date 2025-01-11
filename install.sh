#!/bin/bash

# Kiểm tra quyền user
DEFAULT_USER="root"
SQL_USER=$(sudo mysql -u $DEFAULT_USER -e "exit" 2>&1)

if echo "$SQL_USER" | grep -q "using password: NO"; then
  # Yêu cầu nhập MySQL user và password
  while true; do
    echo "Automatic SQL backup uses root user as default, please enter information."
    read -e -i "$DEFAULT_USER" -p "Enter MySQL username [default: $DEFAULT_USER]: " MYSQL_USER
    MYSQL_USER=${MYSQL_USER:-$DEFAULT_USER}  # Nếu không nhập, dùng giá trị mặc định là $DEFAULT_USER
    MYSQL_USER=$(echo "$MYSQL_USER" | tr -cd '\11\12\15\40-\176')
    # Kiểm tra nếu username trống
    if [ -z "$MYSQL_USER" ]; then
      echo "MySQL username cannot be empty. Please enter a valid username."
    else
      break
    fi
  done

  while true; do
    read -p "Enter MySQL password: " MYSQL_PASSWORD
    echo ""
    MYSQL_PASSWORD=$(echo "$MYSQL_PASSWORD" | xargs)

    # Kiểm tra nếu password trống
    if [ -z "$MYSQL_PASSWORD" ]; then
      echo "Password cannot be empty. Please enter a valid password."
    else
      # Kiểm tra kết nối với thông tin đã nhập
      CONNECT_TEST=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "exit" 2>&1)
      if echo "$CONNECT_TEST" | grep -q "Access denied"; then
        echo "Incorrect username or password."
      else
        #echo "Login successful!"
        break
      fi
    fi
  done

  # Cập nhật file config
  CONFIG_FILE="./mysqlbackup.cnf"
  if [ -f "$CONFIG_FILE" ]; then
    sed -i "s|^#\?MYSQL_USER=.*|MYSQL_USER=\"$MYSQL_USER\"|" "$CONFIG_FILE"
    sed -i "s|^#\?MYSQL_PASSWORD=.*|MYSQL_PASSWORD=\"$MYSQL_PASSWORD\"|" "$CONFIG_FILE"
    echo "MySQL is ready, please proceed with the configuration steps:"
    echo ""
  else
    echo "Configuration file $CONFIG_FILE not found. Unable to update MySQL credentials."
    exit 1
  fi
fi

# Bắt đầu cấu hình
DEFAULT_DIR="/var/backups/db"
echo "Step 1: Backup Storage Path (default: $DEFAULT_DIR)"
while true; do
  read -e -i "$DEFAULT_DIR" -p "Press Enter to use default, or enter custom storage path: " BACKUP_DIR
  BACKUP_DIR=$(echo "$BACKUP_DIR" | xargs)
  BACKUP_DIR=${BACKUP_DIR:-$DEFAULT_DIR}

  # Kiểm tra xem đường dẫn có phải là một thư mục hợp lệ không
  if [ -d "$BACKUP_DIR" ] || mkdir -p "$BACKUP_DIR"; then
    break
  else
    echo "Invalid directory. Please enter a valid directory path."
  fi
done

echo "Backup directory is ready at: $BACKUP_DIR"

# Kiểm tra server có cài các công cụ gửi mail hay không
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

    if [ -z "$SEND_EMAIL" ]; then
      EMAIL_OPTION="no_attachments"
      echo "No option selected, defaulting to send mail without attachments ($EMAIL_OPTION)"
      break
    elif [ "$SEND_EMAIL" = "y" ] || [ "$SEND_EMAIL" = "Y" ]; then
      EMAIL_OPTION="attachments"
      echo "Email will be sent with attachments ($EMAIL_OPTION)"
      break
    elif [ "$SEND_EMAIL" = "d" ] || [ "$SEND_EMAIL" = "D" ]; then
      EMAIL_OPTION="no_attachments"
      echo "Email will be sent with no attachments ($EMAIL_OPTION)"
      break
    elif [ "$SEND_EMAIL" = "n" ] || [ "$SEND_EMAIL" = "N" ]; then
      EMAIL_OPTION="no_email"
      echo "Email sending feature has been disabled ($EMAIL_OPTION)"
      break
    else
      echo ""
      echo "Invalid input. Please enter 'y', 'd', or 'n'."
    fi
  done

  # Nếu người dùng chọn gửi email, yêu cầu cấu hình thêm
  if [ "$EMAIL_OPTION" = "attachments" ] || [ "$EMAIL_OPTION" = "no_attachments" ]; then
    echo ""
    echo "Step 3: Configure Email Settings"
    read -p "Enter the recipient's email address: " EMAIL_TO

    # Hàm kiểm tra định dạng email hợp lệ
    is_valid_email() {
      local email="$1"
      echo "$email" | grep -E -q "^[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)*@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}$"
      return $? # Trả về mã thoát của grep (0 nếu hợp lệ, 1 nếu không hợp lệ)
    }

    EMAIL_TO=$(echo "$EMAIL_TO" | tr -cd '\11\12\15\40-\176')

    while ! is_valid_email "$EMAIL_TO"; do
      echo "Invalid email format. Please enter a valid recipient's email address."
      read -p "Enter the recipient's email address: " EMAIL_TO
      EMAIL_TO=$(echo "$EMAIL_TO" | tr -cd '\11\12\15\40-\176')
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
CRON_FILE="${CRON_DIR}runsqlbackup"
sudo cp ./runsqlbackup "$CRON_DIR"
sudo chmod +x "$CRON_FILE"
echo "Backup script copied to $CRON_FILE and set as executable."

# Copy file cấu hình
CONFIG_DIR="/etc/automysqlbackup/"
CONFIG_FILE="${CONFIG_DIR}mysqlbackup.cnf"
sudo mkdir -p ${CONFIG_DIR}
sudo cp ./mysqlbackup.cnf "$CONFIG_FILE"
sudo cp ./sendmail "${CONFIG_DIR}/sendmail"

# Cập nhật cấu hình trong file script
echo ""
echo "Step 5: Configuring Backup Script... "

if [ "$BACKUP_DIR" != "/var/backups/db" ]; then
  sed -i "s|^#\?BACKUP_DIR=.*|BACKUP_DIR=\"$BACKUP_DIR\"|" "$CONFIG_FILE"
fi

sed -i "s|^#\?EMAIL_TO=.*|EMAIL_TO=\"$EMAIL_TO\"|" "$CONFIG_FILE"
sed -i "s|^#\?SENDER_NAME=.*|SENDER_NAME=\"$SENDER_NAME\"|" "$CONFIG_FILE"
sed -i "s|^#\?EMAIL_OPTION=.*|EMAIL_OPTION=\"$EMAIL_OPTION\"|" "$CONFIG_FILE"

# Revert
sed -i "s|^#\?MYSQL_USER=.*|MYSQL_USER=\"$DEFAULT_USER\"|" "./mysqlbackup.cnf"
sed -i "s|^#\?MYSQL_PASSWORD=.*|MYSQL_PASSWORD=\"\"|" "./mysqlbackup.cnf"

# Xoá ký tự \r khi sao chép từ windows
sudo find $CONFIG_DIR -type f -name "*.cnf" -exec sed -i 's/\r//g' {} \;
sudo sed -i 's/\r//g' $CRON_FILE

# Hoàn thành
echo "Setup completed! All database backups are now scheduled to run daily."

echo ""
echo "You can use sudo /etc/cron.daily/runsqlbackup for testing."
