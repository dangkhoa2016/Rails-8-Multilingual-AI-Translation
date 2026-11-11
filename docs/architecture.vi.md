# Kiến trúc hệ thống

> 🌐 Language / Ngôn ngữ: **Tiếng Việt** | [English](architecture.md)

## Thành phần

Ứng dụng là không gian quản trị Rails 8.1 server-rendered, sử dụng PostgreSQL, Devise/Warden, Pundit, Rack::Attack, Solid Queue, Solid Cache, Turbo, Stimulus và Tailwind CSS.

~~~text
Trình duyệt quản trị
  -> HTTPS / Rails controller / phân quyền
  -> PostgreSQL: users, translation requests, runs, dispatches, deployments
  -> Solid Queue: jobs gửi yêu cầu và truy vấn trạng thái
  -> HTTP client: endpoint provider triển khai độc lập
  <- phản hồi hoặc trạng thái job ở provider
  -> Turbo Streams: cập nhật các thẻ kết quả so sánh
~~~

Rails không tải hoặc chạy trực tiếp các model dịch thuật. Dịch vụ provider có thể đặt độc lập trên Modal, Lightning.ai hoặc một nền tảng tương thích khác.

## Bản ghi dữ liệu chính

- `User`: danh tính quản trị và mật khẩu được xác thực bằng Devise.
- `InferenceConnection`: provider, giao thức adapter, HTTPS base URL và Bearer token được mã hóa.
- `TranslationModel`: định danh model ổn định, triển khai hoạt động được cấu hình riêng.
- `ModelDeployment`: lịch sử ánh xạ model với connection và remote identifier theo phiên bản.
- `TranslationRequest`: văn bản nguồn, nhãn ngôn ngữ, lựa chọn model và xác nhận chi phí.
- `TranslationDispatch`: một lần gửi yêu cầu đến provider với idempotency key và trạng thái.
- `TranslationRun`: kết quả và trạng thái riêng của một model.
- `SecurityEvent` và `InferenceSettingEvent`: nhật ký xác thực và cấu hình.

## Ranh giới tin cậy

Trình duyệt không nhận Bearer token hoặc khóa mã hóa Rails. HTTP adapter chỉ gọi các endpoint qua bước kiểm tra. Active Record Encryption bảo vệ credential lúc lưu trữ; HTTPS và chính sách network egress bảo vệ yêu cầu đi ra. Người deploy cần cấu hình trusted proxy và giới hạn outbound network.

## Xử lý bất đồng bộ

Một yêu cầu có thể gọi độc lập từ một đến bốn model. Làm mới trạng thái sử dụng GET, không tạo thêm POST có phí. Không tự retry POST có kết quả chưa chắc chắn. Xem [Luồng dịch thuật](translation-workflow.vi.md) và [Tích hợp API](api.vi.md).
