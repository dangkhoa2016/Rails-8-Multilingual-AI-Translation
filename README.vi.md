# Rails 8 Multilingual AI Translation

> 🌐 Language / Ngôn ngữ: [English](README.md) | **Tiếng Việt**

[![CI](https://github.com/dangkhoa2016/Rails-8-Multilingual-AI-Translation/actions/workflows/ci.yml/badge.svg)](https://github.com/dangkhoa2016/Rails-8-Multilingual-AI-Translation/actions/workflows/ci.yml) ![Rails 8.1](https://img.shields.io/badge/Rails-8.1-red) ![Ruby 3.3](https://img.shields.io/badge/Ruby-3.3.8-red) ![MIT](https://img.shields.io/badge/License-MIT-blue)

Ứng dụng Rails 8 dành cho admin dịch và so sánh kết quả từ nhiều dịch vụ AI khác nhau. [English](README.md).

## Chức năng đã viết

- Devise 5 + Warden xác thực admin, Pundit phân quyền, Rack::Attack và PostgreSQL/Solid Cache giới hạn truy cập; Rails 8, Tailwind CSS, Hotwire, Solid Queue.
- Giao diện song ngữ tiếng Anh / tiếng Việt bằng Rails I18n, không giới hạn ngôn ngữ nguồn/đích của bản dịch.
- Ba theme Sáng / Tối / Tự động; chế độ Tự động thay đổi theo theme hệ điều hành.
- Giới hạn đăng nhập bằng PostgreSQL, hết hạn phiên, vô hiệu hóa phiên khi đổi mật khẩu, xác nhận lại mật khẩu khi sửa cài đặt quan trọng và xác thực WebSocket/Turbo Streams.
- Danh mục bốn model: Hy-MT2, Index-Translate, Gemma 4 và Qwen3.5.
- Trang System Settings để tạo kết nối theo từng provider/endpoint/token, có thể dùng chung kết nối giữa nhiều model.
- Bearer token được mã hóa bằng Active Record Encryption; ô token cũ không hiển thị plaintext.
- Bảng deployment phiên bản hóa; lịch sử dịch vẫn tham chiếu deployment đã dùng.
- Mỗi model được gửi riêng đến đúng connection; lưu idempotency key trước HTTP POST.
- Dịch bất đồng bộ qua Translation Gateway v1; hỗ trợ OpenAI-compatible chat completions khi endpoint thực sự tương thích.
- Mỗi model có card kết quả riêng; hiển thị unsupported language, lỗi API và mock result rõ ràng.
- Xem lịch sử/trạng thái chỉ dùng GET, không tự động phát sinh inference mới khi refresh.

## Cài đặt

Yêu cầu Ruby 3.3+, PostgreSQL 15+, kết nối RubyGems để cài gem. Không cần GPU ở phía Rails.

```bash
bundle install
bin/rails db:encryption:init
# Export ba biến AR_ENCRYPTION_* nhận được từ lệnh trên.
# Export ADMIN_EMAIL, ADMIN_PASSWORD để tạo admin đầu tiên.
bin/setup
bin/rails server
# Terminal thứ hai:
bin/jobs start
```

Biến môi trường tham khảo trong `.env.example`. **Không đưa URL chứa secret, token, password hoặc encryption key vào source code hoặc commit.** Production nên sử dụng ba kết nối PostgreSQL dành cho dữ liệu ứng dụng, Solid Queue và Solid Cache; cấu hình `CACHE_DATABASE_URL` cho bộ đếm rate limit dùng chung.

### Sử dụng

1. Chọn **English / Tiếng Việt** và **Sáng / Tối / Tự động** ngay trên thanh điều hướng (cả khi chưa đăng nhập); lựa chọn được lưu vào cookie có chữ ký.
2. Vào `/login` bằng admin đã seed.
3. Mở `/admin/settings/inference` → tạo ít nhất một inference connection. Chọn provider, đúng API protocol, HTTPS base URL và Bearer token, sau đó bật connection.
4. Tại model card, chọn connection đã có, nhập remote model identifier và Activate deployment.
5. Vào `/admin/translations/new`, nhập nhãn ngôn ngữ bất kỳ, văn bản, chọn 1–4 model rồi xác nhận trước khi dịch.
6. Mở trang kết quả để so sánh bản dịch. Với Gateway v1, polling là GET; timeout POST không tạo lại yêu cầu tính phí.

**Lưu ý:** Chọn bốn model có thể phát sinh bốn lần model-run tính phí. `Check catalog` không gửi POST inference nhưng vẫn có thể đánh thức hosting. Model báo `UNSUPPORTED_LANGUAGE_PAIR` không có nghĩa hệ thống có thể đoán đúng mọi ngôn ngữ được hỗ trợ.

### Chính sách bảo mật

- **Rate limit đăng nhập:** 12 lượt / 5 phút theo IP, 5 lượt / 10 phút theo IP + tài khoản. Bộ đếm dùng PostgreSQL chung cho mọi worker, không khóa tài khoản toàn hệ thống chỉ vì một IP nhập sai.
- **Phiên đăng nhập:** hết hạn sau 30 phút không hoạt động hoặc tối đa 12 giờ; đổi mật khẩu sẽ làm phiên cũ không còn hợp lệ.
- **Sửa System Settings:** phải xác nhận lại mật khẩu nếu đã quá 10 phút từ lần xác thực gần nhất. Thay đổi bị chặn phải được gửi lại sau khi xác nhận.
- **Mật khẩu admin:** tối thiểu 14 ký tự khi tạo/đổi. Chạy lại `db:seed` không đặt lại mật khẩu admin đã tồn tại.
- **Giới hạn tác vụ:** 8 yêu cầu dịch/phút/admin, 12 lần làm mới trạng thái/phút/admin, 20 thay đổi settings/10 phút, 4 lần kiểm tra kết nối/phút.
- **Độ an toàn:** cookie phiên được giới hạn `Secure` trong production, `HttpOnly`, `SameSite=Lax`; có CSRF, CSP có nonce, ẩn nội dung nhạy cảm khỏi browser cache.

Chi tiết: [Bảo mật và bản địa hóa](docs/SECURITY_AND_LOCALIZATION.vi.md).

### Kiểm thử

```bash
RAILS_ENV=test bin/rails db:prepare
bin/rails test
```

CI sử dụng fixture và mock, không gọi GPU. Đã chạy Minitest trên Ruby 3.3.8, Rails 8.1.4.1 và PostgreSQL 16: **28 tests, 205 assertions, 0 failures, 0 errors**. Migration, kiểm tra Zeitwerk và build Tailwind CSS cũng thành công. Chưa nghiệm thu trực tiếp với các endpoint inference bên ngoài hoặc kiểm thử trình duyệt đầy đủ.

### Phạm vi còn lại

Tối ưu group submit `/v1/jobs/benchmarks`, giao diện đối soát chuyên sâu cho các dispatch chưa rõ trạng thái, quản lý attempts và kiểm thử integration với các hosting khác nhau. Boot, migration và Minitest đã được kiểm chứng; trước khi đưa lên production vẫn cần nghiệm thu endpoint thật, kiểm tra bảo mật độc lập và quy trình vận hành.

Repository inference tham chiếu: [Multilingual Translation AI Inference](https://github.com/dangkhoa2016/Multilingual-Translation-AI-Inference). Rails không tải model GGUF và không chạy GPU.

## License

MIT — © Đăng Khoa <i.am@dangkhoa.dev>. Giấy phép model/API thuộc về từng nguồn riêng.
