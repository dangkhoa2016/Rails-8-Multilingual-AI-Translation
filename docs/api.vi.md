# Tích hợp API provider

> 🌐 Language / Ngôn ngữ: **Tiếng Việt** | [English](api.md)

## Adapter hỗ trợ

- `translation_gateway_v1`: giao thức dịch vụ bất đồng bộ của [repository inference](https://github.com/dangkhoa2016/Multilingual-Translation-AI-Inference). Truy vấn trạng thái dùng GET.
- `openai_chat_completions`: adapter tùy chọn khi provider hỗ trợ giao thức chat-completions tương thích. Khả năng tương thích phải được kiểm chứng trên endpoint thật, không suy từ tên nhà cung cấp hosting.

Adapter được chọn theo connection; remote model identifier thuộc deployment. Tên provider như Modal hay Lightning.ai không đồng nghĩa với giao thức API.

## Route của ứng dụng Rails

- `GET /login` và `POST /login`: đăng nhập quản trị.
- `DELETE /logout`: đăng xuất.
- `GET /admin/translations/new`, `POST /admin/translations`: tạo yêu cầu dịch.
- `GET /admin/translations/:id`: xem kết quả từng model.
- `POST /admin/translations/:id/refresh_status`: yêu cầu polling an toàn.
- `PATCH /admin/translations/:id/prefer`: chọn kết quả hoàn thành ưa thích.
- `GET /admin/settings/inference`: quản lý connection và deployment.
- `GET /admin/security`: tổng quan bảo mật.

Đây là các route ứng dụng Rails yêu cầu xác thực, **không phải** REST API dịch thuật công khai cho mọi client.

## Mạng và credential

Base URL connection phải là HTTPS host public trên cổng 443, không chứa credential, query hay fragment. Client kiểm tra DNS/IP, TLS, pin đích và không cho redirect. Token được mã hóa trong PostgreSQL, không xuất cho trình duyệt.

## Ngữ nghĩa lỗi

Provider có thể trả `UNSUPPORTED_LANGUAGE_PAIR` khi không hỗ trợ cặp ngôn ngữ. Timeout hoặc phản hồi chưa chắc chắn khác với lỗi đã xác nhận. Không tự gửi lại POST có thể tính phí; GET polling có thể lặp theo chính sách giới hạn.

Để xem đầy đủ request fields, mã lỗi và giới hạn, hãy đọc adapter nguồn và repository inference. Code adapter Rails của revision đang chạy là cơ sở đối chiếu chính xác.
