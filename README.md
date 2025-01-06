# bk-sqls
Backup SQL: Chức năng tự động sao lưu database và gửi mail đính kèm file.

Cách sử dụng:
1. Upload file bk-sqls lên /etc/cron.daily
2. Chạy lệnh phân quyền: sudo chmod +x /etc/cron.daily/bk-sqls

Note: 
Sửa thông tin email gửi và nhận, server phải được cài đặt sendmail và cronjob hoạt động.
Các file sql được sao lưu tự động hàng ngày/tuần/tháng trong /var/backups/db
