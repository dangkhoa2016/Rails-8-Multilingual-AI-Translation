# Mô hình bảo mật

> 🌐 Language / Ngôn ngữ: **Tiếng Việt** | [English](security.md)

## Danh tính và truy cập

Devise/Warden xác thực quản trị bằng password hash. Đăng ký công khai được tắt. Pundit cùng kiểm tra role tại server bảo vệ các thao tác đặc quyền; bản ghi dịch được giới hạn theo người tạo. Khi thay đổi cài đặt nhạy cảm phải xác thực lại mật khẩu gần đây.

Session trình duyệt được ký/mã hóa và có giới hạn idle lẫn thời hạn tuyệt đối. Đổi mật khẩu làm session cũ không còn hợp lệ nhờ fingerprint. Cookie ngôn ngữ/theme độc lập với credential.

## Giới hạn request

Rack::Attack xử lý giới hạn ở middleware; `LoginThrottle` dùng PostgreSQL để thực thi giới hạn đăng nhập và thao tác admin bằng bộ đếm atomic giữa các process. Production phải dùng Solid Cache trên database chia sẻ, không sử dụng memory cache riêng từng worker. Reverse proxy cần chống giả mạo địa chỉ IP client.

## Secret và kết nối mạng

Bearer token sử dụng Active Record Encryption. Không đưa token vào log, lỗi, template, CI artifact hoặc JavaScript trình duyệt. URL validation chặn endpoint nội bộ/không public. Phòng vệ nhiều lớp vẫn cần egress policy, DNS/proxy tin cậy và TLS termination.

## Cấu hình production và bảo vệ bí mật

Khi `RAILS_ENV=production`, Rails từ chối khởi động nếu thiếu `SECRET_KEY_BASE`, ba biến khóa Active Record Encryption hoặc `DATABASE_URL`, `QUEUE_DATABASE_URL`, `CACHE_DATABASE_URL`. Các khóa mã hóa phải đủ dài và khác nhau; ba URL PostgreSQL phải dùng database khác nhau để tránh nhầm lẫn dữ liệu ứng dụng, hàng đợi và cache. Thông báo lỗi chỉ nêu tên biến, không in giá trị bí mật hay chuỗi kết nối.

Không đưa khóa vào Git, workflow hoặc HTML gửi tới trình duyệt. Khi triển khai sau reverse proxy, TLS phải kết thúc tại lớp tin cậy, chặn truy cập trực tiếp không tin cậy tới Rails và làm sạch các forwarded headers. Production đã bật `assume_ssl` và `force_ssl`; session cookie dùng Secure/HttpOnly/SameSite=Lax. Chống SSRF bao gồm kiểm tra hostname, DNS/IP công khai, ghim IP kết nối TLS và không theo redirect; vẫn cần firewall egress để phòng vệ nhiều lớp.

Rails cũng lọc khỏi request logs các thuật ngữ nguồn/đích, ghi chú riêng, snapshot Glossary, văn bản dịch, phản hồi provider và khóa request. Cần áp dụng bộ lọc tương tự ở hệ thống theo dõi lỗi/log bên ngoài.

## Bảo vệ trình duyệt và CSP

Ứng dụng yêu cầu CSRF token với thao tác ghi, dùng session cookie HttpOnly/SameSite=Lax, giới hạn tài nguyên riêng cho admin đã đăng nhập và trả no-store cho trang chứa dữ liệu nhạy cảm. CSP chặn `unsafe-inline`, `unsafe-eval` và nhúng iframe. Stylesheet cố định của thanh tiến trình Turbo được cấp quyền qua **đúng hash SHA-256**, không nới lỏng `style-src` thành unsafe-inline. Cần kiểm tra lại hash khi nâng cấp Turbo. Xem [kiểm thử Chromium / Playwright tùy chọn](testing.vi.md#nghiệm-thu-trên-trình-duyệt-chromium--playwright), bao gồm kiểm tra render thuật ngữ không tin cậy mà không gọi inference.

## Báo cáo lỗ hổng

Với lỗ hổng nghi ngờ, dùng kên riêng trong [Security Policy](../.github/SECURITY.vi.md). Không đăng public issue chứa thông tin khai thác hoặc secret.

## Rủi ro còn lại

Các bài test hiện tại không đồng nghĩa đã có MFA, analytics bảo mật đầy đủ, penetration test trên trình duyệt hay nghiệm thu vận hành production. Xem [Bảo mật và bản địa hóa](SECURITY_AND_LOCALIZATION.vi.md) và [Trạng thái triển khai](IMPLEMENTATION_STATUS.vi.md).
