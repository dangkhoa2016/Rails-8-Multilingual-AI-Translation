# Trạng thái triển khai và kiểm chứng

> 🌐 Language / Ngôn ngữ: [English](IMPLEMENTATION_STATUS.md) | **Tiếng Việt**

Repository chứa ứng dụng Rails 8 Multilingual AI Translation với Devise/Warden, Rack::Attack, Pundit, Security Center, bản địa hóa EN/VI, giao diện sáng/tối/auto, kết nối provider riêng, token mã hóa và dispatch riêng từng model.

## Kết quả kiểm chứng runtime

Đã kiểm chứng với Ruby **3.3.8**, Rails **8.1.4.1** và PostgreSQL **16**:

- `bundle install` và Rails boot thành công.
- `bin/rails db:prepare` chạy migration database ứng dụng và Solid Queue thành công.
- `bin/rails test`: **114 tests, 1490 assertions, 0 failures, 0 errors, 0 skips**.
- `bin/rails zeitwerk:check`: đạt.
- `bin/rails tailwindcss:build`: đạt.
- Không dùng inference thật, GPU hoặc credential provider trong các bài test.

Minitest bao phủ tùy chọn giao diện, session timeout, login throttle, phân quyền admin, xác thực lại mật khẩu, endpoint safety, adapter và idempotency. CSRF được bật ở production; môi trường test tắt kiểm tra browser token phục vụ mô phỏng request.

## Chức năng đã triển khai

- Rails 8.1, PostgreSQL, Solid Queue, Tailwind CSS, Turbo và Stimulus.
- UI EN/VI và theme sáng/tối/auto.
- Quyền admin, HMAC + PostgreSQL throttle, signed session cookie, xác thực lại và Action Cable được xác thực.
- Bốn model catalog, connection dùng lại được và Bearer token mã hóa.
- Lịch sử deployment theo phiên bản, adapter và kiểm tra HTTPS outbound an toàn.
- Xác nhận chi phí, dispatch riêng theo model, result card độc lập, sao chép/chọn ưa thích và polling chỉ đọc.
- Idempotency request/dispatch; dùng trạng thái uncertain thay vì tự retry POST có phí.
- Đối soát định kỳ có giới hạn với dispatch bị kẹt, nối lại GET polling chỉ khi bật tùy chọn, không tự gửi lại POST inference; kiểm thử end-to-end bốn model trên ba PostgreSQL database sạch.
- Lịch sử phân trang/lọc và xuất TXT/Markdown/JSON theo quyền sở hữu.
- Glossary riêng cho từng admin, mã hóa và có thể bật/tắt; khi dịch qua OpenAI-compatible, hệ thống kiểm tra adapter và đóng băng snapshot có giới hạn trước dispatch. Hợp đồng Gateway v1 không đổi.
- Trung tâm trợ giúp EN/VI về giới hạn, bảo mật, xuất dữ liệu và yêu cầu chưa rõ kết quả.
- Đã nghiệm thu Chromium, Firefox và WebKit: JavaScript thực, preference, Glossary/XSS, responsive 320–768 px, menu mobile, CSRF/CSP; có workflow browser GitHub Actions thủ công. Production kiểm tra fail-fast khóa/secret, ba database PostgreSQL riêng và lọc log thuật ngữ riêng tư. Đã chạy trên ba database PostgreSQL sạch cùng khóa mã hóa thử nghiệm mới.

## Hạng mục cần kiểm chứng trước production

- Nghiệm thu inference live trên từng provider có cấu hình, sau khi cho phép phát sinh chi phí.
- Review/penetration test độc lập trên môi trường triển khai và xác minh reverse-proxy/TLS thực tế (đã đạt Chromium, Firefox và WebKit trên preview cục bộ).
- Diễn tập restart/failover worker production và đối soát thực tế với provider cho job có kết quả chưa rõ (logic đối soát CPU-only đã được kiểm thử).
- Egress policy, trusted proxy/real IP, TLS, key rotation và monitoring.
- Tùy chọn group benchmark và mở rộng adapter theo provider.

Đây là nền tảng đã kiểm thử runtime, **không phải chứng nhận bảo mật production**. Không đưa credential và Rails encryption keys vào source control.

[Chỉ mục tài liệu](README.vi.md)
