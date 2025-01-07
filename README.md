# bk-sqls
Backup SQL: Chức năng tự động sao lưu database và gửi mail đính kèm file.

Cách sử dụng:

Support: 
1. Linux hoặc các bản phân phối dựa trên Linux
2. Sendmail, exim4, hoặc postfix (nếu cần gửi đính kèm file)   

Cách cài đặt:
--- Thủ công
1. Tải về file bk-sqls
2. Tuỳ chỉnh thông tin như đường dẫn để sao lưu, email .v.v
3. Tải file bk-sqls lên thư mục /etc/cron.daily
2. Chạy lệnh phân quyền: sudo chmod +x /etc/cron.daily/bk-sqls

--- Tự động
1. Tải về file zip và giải nén
2. Chạy sh install.sh từ terminal (cần quyền sudo hoặc root)
3. Làm theo các bước hiển thị trên terminal

Note: 
Sửa thông tin email gửi và nhận, server phải được cài đặt sendmail và cronjob hoạt động.
Các file sql được sao lưu tự động hàng ngày/tuần/tháng trong thư mục mặc định /var/backups/db
