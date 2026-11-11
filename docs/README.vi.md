# Hướng dẫn tài liệu

> 🌐 Language / Ngôn ngữ: **Tiếng Việt** | [English](README.md)

Đây là điểm bắt đầu để đọc kiến trúc, cấu hình, quy trình dịch, giao tiếp provider, bảo mật, vận hành và phạm vi đã kiểm chứng của Rails 8 Multilingual AI Translation.

## Danh mục

| Chủ đề | Tài liệu |
|---|---|
| Kiến trúc và mô hình dữ liệu | [Kiến trúc](architecture.vi.md) |
| Cấu hình local và production | [Cấu hình](configuration.vi.md) |
| Quy trình dịch và so sánh | [Luồng dịch thuật](translation-workflow.vi.md) |
| Giao tiếp với API provider | [Tích hợp API](api.vi.md) |
| Xác thực và ranh giới bảo mật | [Bảo mật](security.vi.md) |
| Kiểm thử và CI | [Kiểm thử](testing.vi.md) |
| Vận hành worker và database | [Vận hành](operations.vi.md) |
| Giới hạn hiện tại | [Giới hạn](limitations.vi.md) |
| Xử lý lỗi thường gặp | [Khắc phục sự cố](troubleshooting.vi.md) |
| Bằng chứng runtime và các bước kiểm chứng còn lại | [Trạng thái triển khai](IMPLEMENTATION_STATUS.vi.md) |
| Đa ngôn ngữ giao diện và chính sách session | [Bảo mật và bản địa hóa](SECURITY_AND_LOCALIZATION.vi.md) |

## Phạm vi

Repository này chứa ứng dụng Rails, không chứa model weights hoặc hạ tầng inference. [Dịch vụ inference](https://github.com/dangkhoa2016/Multilingual-Translation-AI-Inference) được deploy riêng và có vòng đời API độc lập. Rails CI chỉ chạy test và mock tại chỗ, không phát sinh lệnh GPU có phí.

Quay lại [README dự án](../README.vi.md).
