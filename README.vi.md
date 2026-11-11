# Rails 8 Multilingual AI Translation

[![CI](https://github.com/dangkhoa2016/Rails-8-Multilingual-AI-Translation/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/dangkhoa2016/Rails-8-Multilingual-AI-Translation/actions/workflows/ci.yml)
![Rails](https://img.shields.io/badge/Rails-8.1-CC0000)
![Ruby](https://img.shields.io/badge/Ruby-3.3.8-CC342D)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791)
![Devise](https://img.shields.io/badge/Auth-Devise%205-425EAA)
![Security](https://img.shields.io/badge/Security-Rack%3A%3AAttack%20%2B%20Pundit-4C9977)
![Language](https://img.shields.io/badge/Docs-EN%20%2F%20VI-2B76C4)
![License](https://img.shields.io/badge/License-MIT-blue)

> 🌐 Language / Ngôn ngữ: [English](README.md) | **Tiếng Việt**

Nền tảng quản trị Rails 8 để so sánh bản dịch từ nhiều endpoint model AI triển khai độc lập. Credential được cấu hình riêng theo model; ứng dụng này không tự host model.

## Chức năng đã viết

- Devise 5 + Warden xác thực admin, Pundit phân quyền, Rack::Attack và PostgreSQL/Solid Cache giới hạn truy cập; Rails 8, Tailwind CSS, Hotwire, Solid Queue.
- Giao diện song ngữ tiếng Anh / tiếng Việt bằng Rails I18n, không giới hạn ngôn ngữ nguồn/đích của bản dịch.
- Dashboard tổng quan với thống kê chỉ đọc database và hướng dẫn cấu hình model; sidebar thu gọn, menu mobile, breadcrumb, SVG icon và giao diện Sáng / Tối / Tự động.
- Translation Studio hỗ trợ nhập tên ngôn ngữ tự do, đổi chiều nguồn/đích, đếm ký tự Unicode, cảnh báo giới hạn theo giao thức và chọn 1–4 model. Trang kết quả có bố cục so sánh 2/4 cột, đánh dấu khác biệt theo dòng mà không gọi inference thêm.
- Giới hạn đăng nhập bằng PostgreSQL, hết hạn phiên, vô hiệu hóa phiên khi đổi mật khẩu, xác nhận lại mật khẩu khi sửa cài đặt quan trọng và xác thực WebSocket/Turbo Streams.
- Danh mục bốn model: Hy-MT2, Index-Translate, Gemma 4 và Qwen3.5.
- Trang System Settings để tạo kết nối theo từng provider/endpoint/token, có thể dùng chung kết nối giữa nhiều model.
- Bearer token được mã hóa bằng Active Record Encryption; ô token cũ không hiển thị plaintext.
- Bảng deployment phiên bản hóa; lịch sử dịch vẫn tham chiếu deployment đã dùng.
- Lịch sử dịch phân trang, lọc theo nhãn ngôn ngữ, UUID phiên, trạng thái và ngày. Xuất TXT, Markdown hoặc JSON chỉ chứa dữ liệu cho phép của phiên đã lưu, không gọi provider; chỉ tài khoản được phép mới đọc nội dung.
- Bảng thuật ngữ riêng cho từng admin: cặp thuật ngữ và ghi chú được mã hóa, có thể thêm/sửa/tắt/xóa, tùy chọn áp dụng khi dịch qua OpenAI-compatible chat. Chỉ thuật ngữ khớp nội dung được lưu thành snapshot mã hóa trước dispatch; Gateway v1 chưa hỗ trợ Glossary.
- Trung tâm trợ giúp EN/VI giải thích giới hạn ký tự, đối chiếu thuật ngữ, bảo mật snapshot, xuất dữ liệu và cách xử lý yêu cầu tính phí chưa rõ trạng thái.
- Nghiệm thu trên ba trình duyệt thực **Chromium, Firefox và WebKit**: chuyển EN/VI giữ bản nháp, menu responsive ở 320–768 px, Glossary CRUD/XSS, CSRF và CSP nghiêm ngặt. Có workflow GitHub Actions thủ công chạy cả ba engine trên database thử nghiệm, không gọi inference. Xem [hướng dẫn kiểm thử](docs/testing.vi.md).
- Mỗi model được gửi riêng đến đúng connection; lưu idempotency key trước HTTP POST.
- Solid Queue đối soát định kỳ: `submitting` bị kẹt được đánh dấu uncertain mà không gửi lại POST; chỉ nối lại GET polling cho `accepted` khi chủ động bật `TRANSLATION_RECOVERY_POLLING_ENABLED=1` (GET có thể đánh thức hosting). Bộ test end-to-end CPU-only kiểm tra luồng bốn model và database PostgreSQL tạo mới.
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

**Giới hạn văn bản:** Translation Gateway v1 hỗ trợ tối đa 1.000 ký tự Unicode/lượt. Studio hiển thị giới hạn đã biết của từng model và từ chối toàn bộ yêu cầu có model vượt giới hạn trước khi lưu phiên dịch hoặc xếp job inference tính phí. Những adapter khác có thể có giới hạn riêng chưa xác định. Rails vẫn giữ giới hạn an toàn 20.000 ký tự Unicode, nhưng không tự chia văn bản dài thành các đoạn để dịch.

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

CI sử dụng fixture và mock, không gọi GPU. Đã chạy Minitest trên Ruby 3.3.8, Rails 8.1.4.1 và PostgreSQL 16: **114 tests, 1490 assertions, 0 failures, 0 errors**. Migration, kiểm tra Zeitwerk và build Tailwind CSS cũng thành công. Đã kiểm thử Chromium, Firefox và WebKit trên preview với database/khóa mới; chưa nghiệm thu inference trực tiếp trên provider bên ngoài hoặc penetration test môi trường production.

### Phạm vi còn lại

Tối ưu group submit `/v1/jobs/benchmarks`, giao diện đối soát chuyên sâu cho các dispatch chưa rõ trạng thái, quản lý attempts và kiểm thử integration với các hosting khác nhau. Boot, migration và Minitest đã được kiểm chứng; trước khi đưa lên production vẫn cần nghiệm thu endpoint thật, kiểm tra bảo mật độc lập và quy trình vận hành.

## Tài liệu

Các hướng dẫn sử dụng quy ước tài liệu tiếng Anh/tiếng Việt của repository, với link chuyển ngôn ngữ ở mỗi trang Markdown:

- [Chỉ mục tài liệu](docs/README.vi.md) — truy cập toàn bộ hướng dẫn kỹ thuật.
- [Kiến trúc](docs/architecture.vi.md) — Rails, PostgreSQL, queue, adapter và ranh giới tin cậy.
- [Cấu hình](docs/configuration.vi.md) — local setup, database URLs và provider connections.
- [Luồng dịch](docs/translation-workflow.vi.md) và [Tích hợp API](docs/api.vi.md) — dispatch, polling và idempotency.
- [Bảo mật](docs/security.vi.md) và [Vận hành](docs/operations.vi.md) — xác thực, credential và biện pháp production.
- [Kiểm thử](docs/testing.vi.md), [Giới hạn](docs/limitations.vi.md), [Xử lý sự cố](docs/troubleshooting.vi.md) và [Trạng thái triển khai](docs/IMPLEMENTATION_STATUS.vi.md).

Thông tin cộng đồng: [Changelog](CHANGELOG.vi.md) · [Đóng góp](.github/CONTRIBUTING.vi.md) · [Chính sách bảo mật](.github/SECURITY.vi.md) · [Hỗ trợ](.github/SUPPORT.vi.md).

Repository inference tham chiếu: [Multilingual Translation AI Inference](https://github.com/dangkhoa2016/Multilingual-Translation-AI-Inference). Rails không tải model GGUF và không chạy GPU.

## License

MIT — © Đăng Khoa <i.am@dangkhoa.dev>. Giấy phép model/API thuộc về từng nguồn riêng.
