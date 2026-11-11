# Bản địa hóa, giao diện và phân quyền

> 🌐 Language / Ngôn ngữ: [English](SECURITY_AND_LOCALIZATION.md) | **Tiếng Việt**

## Ngôn ngữ giao diện

Ứng dụng hỗ trợ **tiếng Anh (`en`) và tiếng Việt (`vi`)** bằng Rails I18n trong `config/locales/en.yml` và `config/locales/vi.yml`. Đây là **ngôn ngữ giao diện**, không phải whitelist của ngôn ngữ nguồn/đích khi dịch. Người dùng có thể đổi ngôn ngữ ở thanh điều hướng kể cả trước khi đăng nhập. Hệ thống lưu lựa chọn trong cookie có chữ ký, `HttpOnly`, hạn một năm và chỉ chấp nhận `en` hoặc `vi`.

Rails dùng `I18n.with_locale` trong `around_action`, tránh làm rò trạng thái locale giữa các HTTP request. Ngôn ngữ giao diện tại thời điểm tạo phiên dịch được lưu ở `translation_requests.ui_locale` để kết quả Turbo Streams cập nhật đồng bộ bằng ngôn ngữ đã chọn. Nếu admin đổi ngôn ngữ khi một job vẫn chạy, lần broadcast tiếp theo vẫn dùng ngôn ngữ lúc tạo job; tải lại trang sẽ hiển thị theo lựa chọn mới.

## Chế độ giao diện

Có ba chế độ **Sáng**, **Tối** và **Tự động**. Lựa chọn được lưu trong cookie ký số `ui_theme`, không cần nhúng script hoặc localStorage. CSS sử dụng biến màu mang ý nghĩa ngữ cảnh. Khi chọn Tự động, giao diện tuân theo `prefers-color-scheme` của hệ điều hành và cập nhật khi hệ điều hành thay đổi.

## Đăng nhập và phân quyền

- Chỉ tài khoản mang role `admin` mới được truy cập lịch sử dịch, System Settings, endpoint/token và các thao tác tạo inference.
- Giới hạn đăng nhập ở mức **12 lượt/5 phút theo IP**, đồng thời **5 lượt/10 phút theo tổ hợp IP + email chuẩn hóa**. Bộ đếm lưu trong PostgreSQL, dùng khóa HMAC để không ghi email hoặc IP thô. Không khóa tài khoản trên toàn bộ IP chỉ do người khác cố tình nhập sai.
- Email không tồn tại hoặc mật khẩu không đúng đều cho cùng một thông báo; dùng phép kiểm tra bcrypt giả khi tài khoản không tồn tại nhằm hạn chế phân biệt thông qua thời gian đáp ứng.
- Xác nhận lại mật khẩu khi sửa settings (connections, deployment, trạng thái model, probe). Tối đa **5 lượt/10 phút/IP+tài khoản** và xác thực lại có hiệu lực **10 phút**. Yêu cầu sửa settings cũ chưa được lưu sẽ cần gửi lại.
- Tối đa **8 lần tạo phiên dịch/phút/admin**, **12 lần yêu cầu cập nhật trạng thái/phút/admin**, **20 lượt chỉnh settings/10 phút** và **4 lần probe kết nối/phút**.
- Session hết hạn sau **30 phút không hoạt động** hoặc **12 giờ kể từ lúc đăng nhập**; đổi `encrypted_password` làm session cũ không còn hợp lệ. Session được làm mới khi đăng nhập, xác nhận lại mật khẩu và được xóa khi đăng xuất.
- Kết nối Action Cable WebSocket cũng kiểm tra cookie đã mã hóa, role admin, thời hạn session và dấu vân tay mật khẩu trước khi cho phép nhận Turbo Streams. Cần kiểm thử thêm việc đóng các WebSocket sống lâu và hủy quyền trên nhiều Rails worker.
- Cookie phiên dùng `Secure` trong production, `HttpOnly`, `SameSite=Lax`; các request thay đổi trạng thái được bảo vệ bằng CSRF.
- Trang quản trị trả `Cache-Control: no-store, private`; CSP giới hạn nguồn script/style cùng origin và dùng nonce ổn định theo session cho Rails importmap/Hotwire, không dùng `unsafe-inline` hay `unsafe-eval`.
- Bearer token provider vẫn mã hóa ở Active Record, không đưa ra HTML, JavaScript, audit log hay phản hồi lỗi.

## Vận hành production

1. Thiết lập **HTTPS** và đúng cấu hình trusted proxies tại reverse proxy. Nếu `request.remote_ip` nhận giá trị giả từ `X-Forwarded-For`, mọi giới hạn theo IP có thể bị vượt qua.
2. Định kỳ chạy `bin/rails security:prune_login_throttles` bằng lịch bảo trì để xóa bộ đếm đã hết hạn. Không cần dùng tác vụ GPU.
3. Các biện pháp này không thay thế **MFA**, chống DDoS ở ingress, giám sát bảo mật, phân quyền network egress hoặc bảo vệ vật lý đối với secret.
4. Cần chạy đầy đủ `bundle install`, migration, test, kiểm thử giao diện, CSP, session, concurrency và reverse proxy trên môi trường staging trước khi triển khai production.
5. Thao tác **Check Connection** dù không gửi lệnh dịch vẫn có thể đánh thức hosting và phát sinh phí.
