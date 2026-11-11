# Phạm vi và giới hạn

> 🌐 Language / Ngôn ngữ: **Tiếng Việt** | [English](limitations.md)

Đây là giao diện quản trị và orchestration dịch thuật bằng Rails, **không phải** tuyên bố đã có dịch vụ production hoàn chỉnh hoặc benchmark model độc lập.

- Có bốn model trong catalog ban đầu; năng lực và ngôn ngữ hỗ trợ phụ thuộc provider.
- Gateway v1 giới hạn một request khoảng 1.000 Unicode code points. Rails chưa có pipeline tự động chia tài liệu và giữ ngữ cảnh văn bản dài.
- Ứng dụng có thể so sánh đầu ra và chọn bản dịch ưa thích; chưa có tự chấm chất lượng, kết quả BLEU/COMET chuẩn hóa hoặc tổng hợp đánh giá chuyên gia.
- Có thể dùng OpenAI chat endpoint nếu tương thích; không phải mọi provider và hosting đều có giao thức như nhau.
- Request có phí với kết quả chưa chắc chắn cần đối soát; hệ thống cố ý tránh retry tự động sau POST không rõ kết quả.
- Security Center chỉ hiển thị một phần sự kiện xác thực/cấu hình, không phải SIEM doanh nghiệp hoàn chỉnh.
- Không có public signup và bộ quản trị vai trò nhiều người dùng đầy đủ. MFA và tự động xoay token cần phát triển riêng.
- CI chỉ dùng CPU, không xác thực trạng thái GPU đang sleep, uptime hosting hoặc chất lượng dịch.
- Nghiệm thu trình duyệt, trusted proxy và provider live phụ thuộc deployment thực tế.

Mốc kiểm thử chính xác được ghi tại [Trạng thái triển khai](IMPLEMENTATION_STATUS.vi.md).
