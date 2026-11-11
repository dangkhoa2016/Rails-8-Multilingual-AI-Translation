# Cấu hình ứng dụng

> 🌐 Language / Ngôn ngữ: **Tiếng Việt** | [English](configuration.md)

## Yêu cầu

- Ruby 3.3 trở lên và dependencies trong `Gemfile.lock`.
- PostgreSQL 15 trở lên, với database ứng dụng, queue và cache.
- Rails 8.1, worker Solid Queue và khả năng kết nối HTTPS tới các endpoint inference.
- Web server Rails không cần GPU.

## Khởi tạo local

~~~bash
bundle install
bin/rails db:encryption:init
# Xuất ba biến AR_ENCRYPTION_* được tạo ra bằng cách an toàn.
# Xuất ADMIN_EMAIL và ADMIN_PASSWORD mạnh, riêng biệt để seed quản trị.
bin/setup
bin/rails server
~~~

Chạy `bin/jobs start` ở terminal thứ hai. Ứng dụng không tự đọc `.env`; `.env.example` chỉ mô tả tên biến. Không commit credential thật.

## Tổ chức database

`DATABASE_URL` lưu dữ liệu ứng dụng. `QUEUE_DATABASE_URL` dành cho Solid Queue. `CACHE_DATABASE_URL` phục vụ bộ đếm Solid Cache dùng chung trong production. Mỗi URL cần trỏ tới database PostgreSQL với quyền phù hợp.

## Cài đặt model/provider

Sau khi đăng nhập tại `/login`, mở `/admin/settings/inference`. Tạo connection đã bật với giao thức `translation_gateway_v1` hoặc `openai_chat_completions` và HTTPS base URL. Nhập Bearer token trong form settings được bảo vệ. Gắn active deployment và remote model identifier cho từng model.

Nhãn provider và giao thức adapter là hai khái niệm độc lập: model trên Modal có thể dùng giao thức khác model trên Lightning.ai. Có thể chuyển model sang connection mới mà không xóa lịch sử triển khai cũ.

## Kiểm tra production

Sử dụng HTTPS, lưu encryption keys qua secret manager, cấu hình trusted proxies, tách quyền PostgreSQL, duy trì queue worker, chặn egress không cần thiết và sao lưu database. Đọc [Bảo mật](security.vi.md) và [Vận hành](operations.vi.md) trước khi mở public.
