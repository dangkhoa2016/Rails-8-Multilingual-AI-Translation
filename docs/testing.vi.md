# Kiểm thử và xác minh

> 🌐 Language / Ngôn ngữ: **Tiếng Việt** | [English](testing.md)

## Các bước kiểm tra CPU-only

~~~bash
bundle install
RAILS_ENV=test bin/rails db:prepare
RAILS_ENV=test bin/rails test
RAILS_ENV=test bin/rails zeitwerk:check
RAILS_ENV=test bin/rails tailwindcss:build
python3 scripts/validate_repository_docs.py
~~~

Bài test sử dụng PostgreSQL và mock HTTP, không cần token provider hoặc GPU. Bộ kiểm thử end-to-end đi qua HTTP controller, Rails adapter, dispatch job, GET polling, lịch sử, xuất kết quả, Glossary snapshot, idempotency, lỗi provider và đối soát an toàn. Không gọi API inference thực tế.

Để nghiệm thu trên database sạch độc lập, tạo ba **PostgreSQL database chỉ dùng cho test** (ứng dụng, queue và cache), cấu hình tương ứng `DATABASE_URL`, `QUEUE_DATABASE_URL`, `CACHE_DATABASE_URL` trong `RAILS_ENV=test`, rồi chạy `bin/rails db:prepare` và `bin/rails test`. Không trỏ các lệnh này tới production database. Kiểm thử database sạch giúp xác minh migration và cấu hình ban đầu, không cần quy trình backup/restore hoặc GPU.

## Nghiệm thu trên trình duyệt (Chromium / Firefox / WebKit)

Trên **preview development nội bộ với tài khoản admin thử nghiệm riêng**, cài Playwright/Chromium độc lập với bundle Rails:

~~~bash
python3 -m pip install playwright
python3 -m playwright install --with-deps chromium firefox webkit
~~~

Chạy Rails trên localhost (ví dụ `bin/rails server -b 127.0.0.1 -p 3108`), sau đó truyền thông tin đăng nhập tài khoản test bằng **biến môi trường, không ghi vào Git hoặc log**:

~~~bash
BROWSER_BASE_URL=http://127.0.0.1:3108 \\
BROWSER_ADMIN_EMAIL=browser-test@example.test \\
BROWSER_ADMIN_PASSWORD='<mat-khau-test-cuc-bo>' \\
for engine in chromium firefox webkit; do
  BROWSER_ENGINE="$engine" python3 scripts/browser_acceptance.py
done
~~~

Script từ chối URL không phải localhost. Các kiểm tra gồm: đăng nhập, chặn người chưa đăng nhập, thuộc tính bảo vệ session cookie, theme/locale và bản nháp chưa gửi, CRUD Glossary có escape HTML, Help Center, History, menu mobile/keyboard, CSP, CSRF và không có POST inference từ trình duyệt. Script tạo và xóa một thuật ngữ gắn mã duy nhất; vì thế chỉ chạy trên **database thử nghiệm**. Nếu quá trình dừng đột ngột, mã fixture được in để dọn thủ công. Script chỉ POST để login, cập nhật preference, CRUD Glossary và thử CSRF bị từ chối; **không gửi job dịch**. Đây là phép thử tùy chọn bên ngoài `bin/rails test` và CI thông thường. Workflow GitHub Actions thủ công `.github/workflows/browser_acceptance.yml` tạo database và credential thử nghiệm rồi chạy cả ba engine khi người dùng chủ động khởi chạy. Chromium, Firefox và WebKit cũng đã được kiểm thử cục bộ. Script kiểm tra lỗi tràn ngang tại các độ rộng 320, 375, 390 và 768 px.

## Phạm vi test

Bộ test hiện có kiểm tra login admin, mật khẩu sai, giới hạn PostgreSQL, hết hạn session, xác nhận lại mật khẩu, phân quyền Pundit, hợp đồng adapter, idempotency và tùy chọn giao diện.

## Nghiệm thu bổ sung

Để nghiệm thu một deployment, cần kiểm tra độc lập trusted proxy/IP, HTTPS, backup database, queue worker, CSRF/CSP trên trình duyệt, outbound restrictions, xoay token, cặp ngôn ngữ theo provider và inference thực tế. Inference live có thể phát sinh chi phí và không nằm trong CI thông thường.

## Ranh giới bằng chứng

CI xanh cho thấy kiểm tra deterministic pass trên một commit cụ thể; không chứng minh chất lượng model, uptime hoặc độ sẵn sàng của hosting bên ngoài. Luôn ghi commit SHA và environment khi báo lỗi.
