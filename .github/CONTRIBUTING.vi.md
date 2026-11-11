# Hướng dẫn đóng góp

> 🌐 Language / Ngôn ngữ: **Tiếng Việt** | [English](CONTRIBUTING.md)

Cảm ơn bạn quan tâm đóng góp cho Rails 8 Multilingual AI Translation. Hãy giữ thay đổi tập trung, có thể kiểm thử và dễ review.

## Thiết lập local

Sử dụng Ruby 3.3+, PostgreSQL 15+ và phiên bản trong `Gemfile.lock`.

~~~bash
bundle install
RAILS_ENV=test bin/rails db:prepare
RAILS_ENV=test bin/rails test
python3 scripts/validate_repository_docs.py
~~~

Thông thường không cần gọi inference có phí hoặc có provider credential để kiểm thử đóng góp.

## Chuẩn code và bảo mật

- Theo Rails conventions, tách services có trách nhiệm rõ và dùng migration khi thay đổi dữ liệu.
- Bảo vệ route admin bằng Pundit và kiểm tra quyền tại server.
- Không nhúng Bearer token, secret, văn bản khách hàng hoặc endpoint nội bộ.
- Không tự gửi lại POST có phí sau timeout chưa xác định.
- Bổ sung regression test khi đổi behavior, giữ CI không cần GPU.

## Chính sách tài liệu

Mọi Markdown được track phải có cặp tiếng Anh/Việt cùng thư mục: `file.md` và `file.vi.md`. Cả hai phải có link chuyển ngôn ngữ qua lại ở đầu file. Cập nhật cả hai phía và kiểm tra relative links. CI thực thi quy tắc này.

## Chất lượng commit

Commit subject rõ nghĩa, body dạng bullet; thay đổi code theo từng chức năng, thông thường dưới 600 dòng thay đổi cho mỗi commit. Cặp tài liệu song ngữ dài có thể ngoại lệ nếu chia nhỏ sẽ khó đọc. Không làm sai lệch kết quả test, bằng chứng release hoặc timestamp.

## Đóng góp

Đề xuất nên nói rõ mục tiêu, thành phần ảnh hưởng, lệnh test đã chạy và tác động bảo mật/chi phí. Xem [PR template](PULL_REQUEST_TEMPLATE.vi.md) và [Hỗ trợ](SUPPORT.vi.md). Báo cáo vấn đề bảo mật qua kênh riêng trong [Security Policy](SECURITY.vi.md).
