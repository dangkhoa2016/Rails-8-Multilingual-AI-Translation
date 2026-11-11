# Chính sách bảo mật

> 🌐 Language / Ngôn ngữ: **Tiếng Việt** | [English](SECURITY.md)

## Phạm vi hỗ trợ

Các bản sửa bảo mật được áp dụng cho nhánh mặc định hiện tại khi xác nhận lỗ hổng. Commit lịch sử và snapshot chưa gắn tag không tự động được hỗ trợ như các release.

## Báo cáo riêng tư

**Không** tạo issue công khai chứa cách khai thác, API token bị lộ, credential hoặc dữ liệu dịch của khách hàng. Sử dụng GitHub private vulnerability reporting nếu được bật, hoặc gửi email **i.am@dangkhoa.dev** với:

- commit SHA bị ảnh hưởng, phiên bản Rails và môi trường deploy;
- các bước tái lập rõ ràng và tác động dự kiến;
- proof of concept đã ẩn thông tin nhạy cảm hoặc log an toàn;
- giải pháp giảm thiểu nếu có.

Không đưa credential production đang hoạt động vào báo cáo. Vấn đề được xem xét khi có thể; không cam kết SLA thời gian phản hồi.

## Bề mặt tấn công

Ứng dụng quản lý session admin, Bearer token provider được mã hóa, cấu hình inference URL, văn bản nguồn của người dùng và request outbound có thể tính phí. Các ranh giới quan trọng: Pundit, rate-limit, SSL/TLS, chỉ endpoint IP public, chống SSRF và không tự retry POST có phí.

## Trách nhiệm triển khai

Sử dụng HTTPS với trusted proxy, bảo vệ khóa bí mật, phân quyền database, hạn chế egress và sao lưu dữ liệu ứng dụng. CI pass không phải chứng nhận an toàn production public. Xem [tài liệu bảo mật kỹ thuật](../docs/security.vi.md).
