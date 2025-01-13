#!/bin/bash

# Kiểm tra quyền user
DEFAULT_USER="root"
SQL_USER=$(sudo mysql -u $DEFAULT_USER -e "exit" 2>&1)

if echo "$SQL_USER" | grep -q "using password: NO"; then
  # Yêu cầu nhập MySQL user và password
  while true; do
    echo "Automatic SQL backup uses root user as default, please enter information."
    read -e -i "$DEFAULT_USER" -p "Enter MySQL username [default: $DEFAULT_USER]: " MYSQL_USER
    MYSQL_USER=${MYSQL_USER:-$DEFAULT_USER} # Nếu không nhập, dùng giá trị mặc định là $DEFAULT_USER
    MYSQL_USER=$(echo "$MYSQL_USER" | tr -cd '\11\12\15\40-\176')
    # Kiểm tra nếu username trống
    if [ -z "$MYSQL_USER" ]; then
      echo "MySQL username cannot be empty. Please enter a valid username."
    else
      break
    fi
  done

  while true; do
    read -sp "Enter MySQL password: " MYSQL_PASSWORD
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
  read -e -i "$DEFAULT_DIR" -p "Use default or enter folder path to backup: " BACKUP_DIR
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
  echo -e "[sendmail] service detected. Do you want to configure email notifications for backup?"
elif command -v exim4 >/dev/null 2>&1; then
  MAIL_SERVICE="exim4"
  echo -e "[exim4] service detected. Do you want to configure email notifications for backup?"
elif command -v postfix >/dev/null 2>&1; then
  MAIL_SERVICE="postfix"
  echo -e "[postfix] service detected. Do you want to configure email notifications for backup?"
else
  echo -e "The server has no mail service."
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
      EMAIL_OPTION="no_email"
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
  echo ""
  echo "Step 3: Configure Email Settings"
  echo "No mail service detected (sendmail, exim, postfix). Skipped."
  EMAIL_TO=""
  SENDER_NAME=""
fi

echo ""
echo "Step 4: Configure Backup Script"

CRON_DIR="/etc/cron.daily/"

# Kiểm tra xem "/usr/local/bin" có nằm trong PATH hay không
if echo "$PATH" | grep -q "/usr/local/bin"; then
  EXECS_DIR="/usr/local/bin/"
else
  EXECS_DIR="${CRON_DIR}"
fi

# Cài đặt script backup vào thư mục phù hợp
EXECS_FILE="${EXECS_DIR}runsqlbackup"
sudo cp ./runsqlbackup "$EXECS_FILE"
sudo chmod +x "$EXECS_FILE"
echo "Backup script copied to $EXECS_FILE and set as executable."

# Cập nhật cấu hình sao lưu hàng ngày
echo ""
echo "Step 5: Creating daily backup configuration... "
CRON_FILE="${CRON_DIR}runsqlbackup"

# Tạo nội dung cho file
echo "#!/bin/sh" >"${CRON_FILE}"
echo "/usr/local/bin/runsqlbackup" >>"${CRON_FILE}"

# Cấp quyền thực thi cho file
sudo chmod +x "${CRON_FILE}"

# Chạy các lệnh bên trong file
#echo "chown -R root:root \$BACKUP_DIR*" >>"${CRON_FILE}"
#echo "find \$BACKUP_DIR* -type f -exec chmod 400 {} \;" >>"${CRON_FILE}"
#echo "find \$BACKUP_DIR* -type d -exec chmod 700 {} \;" >>"${CRON_FILE}"

# Cấp quyền cho file vừa tạo
chmod +x "${CRON_FILE}"

# Copy file cấu hình
CONFIG_DIR="/etc/automysqlbackup/"
CONFIG_FILE="${CONFIG_DIR}mysqlbackup.cnf"
sudo mkdir -p ${CONFIG_DIR}
sudo cp ./mysqlbackup.cnf "$CONFIG_FILE"
sudo cp ./sendmail "${CONFIG_DIR}/sendmail"

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
sudo sed -i 's/\r//g' $EXECS_FILE

if [ -f "$CONFIG_FILE" ] && [ -f "$CRON_FILE" ] && [ -f "$EXECS_FILE" ]; then
  # Hoàn thành
  echo "Setup completed! All database backups are now scheduled to run daily."
  echo ""
  echo "You can use sudo $EXECS_FILE for testing."
else
  echo "One or more files are missing:"
  [ ! -f "$CONFIG_FILE" ] && echo "$CONFIG_FILE does not exist."
  [ ! -f "$CRON_FILE" ] && echo "$CRON_FILE does not exist."
  [ ! -f "$EXECS_FILE" ] && echo "$EXECS_FILE does not exist."
fi

