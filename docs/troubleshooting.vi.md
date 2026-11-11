# Khắc phục sự cố

> 🌐 Language / Ngôn ngữ: **Tiếng Việt** | [English](troubleshooting.md)

## Đăng nhập trả HTTP 429

Bộ đếm SQL hoặc Rack::Attack đang áp giới hạn. Kiểm tra header `Retry-After` và Security Center; xác nhận proxy chuyển đúng IP client đáng tin cậy. Không tùy tiện xóa bộ đếm trên môi trường public.

## Model bị tắt hoặc không khả dụng

Kiểm tra trạng thái model, active deployment, connection đang bật, Bearer token đã lưu và remote model identifier. Xác minh giao thức trước khi gọi inference thật.

## Endpoint inference bị từ chối

Chỉ chấp nhận HTTPS base URL công khai trên cổng 443. Xóa path, query, credential nhúng URL và hostname nội bộ. DNS phải phân giải hoàn toàn về IP public hợp lệ. Không tắt kiểm tra SSRF để chạy tạm endpoint nội bộ.

## Request dịch pending hoặc uncertain

Kiểm tra worker Solid Queue và dispatch/remote job ID đã lưu. Timeout sau POST không chứng minh thất bại; sử dụng truy vấn trạng thái an toàn hoặc đối soát provider, thay vì retry yêu cầu có phí.

## Lỗi database, mã hóa hoặc assets

Xác minh ba kết nối PostgreSQL; kiểm tra encryption environment keys nhưng không in giá trị. Dùng `RAILS_ENV=test bin/rails db:prepare` cho môi trường test và `bin/rails zeitwerk:check` hoặc `bin/rails tailwindcss:build` để chẩn đoán code/assets.

Khi báo lỗi, chỉ gửi log an toàn, commit SHA chính xác và các bước tái lập. Xem [Hỗ trợ](../.github/SUPPORT.vi.md).
