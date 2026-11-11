# Hướng dẫn vận hành

> 🌐 Language / Ngôn ngữ: **Tiếng Việt** | [English](operations.md)

## Các service

Chạy Rails web (`bin/rails server`) và worker Solid Queue (`bin/jobs start`) thành các process được giám sát độc lập. Cấu hình `DATABASE_URL`, `QUEUE_DATABASE_URL` và `CACHE_DATABASE_URL` cho PostgreSQL ứng dụng, queue và cache. Bảo vệ Active Record encryption keys và application secrets thông qua cơ chế môi trường an toàn.

## Giám sát

Theo dõi tỉ lệ HTTP status, job failure, tuổi queue, kết nối PostgreSQL, sự kiện xác thực và latency từng provider. Không ghi văn bản nguồn, bản dịch, Bearer token hoặc secret key vào log vận hành thường lệ. Tránh polling trạng thái quá nhiều, đặc biệt khi GPU hosting có cơ chế sleep.

## Khôi phục

Khi provider không khả dụng, giữ trạng thái failed hoặc uncertain rõ ràng. Trước khi thử lại lệnh có phí, cần đối soát remote job ID và phản hồi provider. Worker restart không chứng minh POST trước đó chưa được xử lý.

## Kiểm tra cấu hình khi khởi động production

Production kiểm tra biến môi trường trước khi phục vụ request: `SECRET_KEY_BASE`, `AR_ENCRYPTION_PRIMARY_KEY`, `AR_ENCRYPTION_DETERMINISTIC_KEY`, `AR_ENCRYPTION_KEY_DERIVATION_SALT`, `DATABASE_URL`, `QUEUE_DATABASE_URL`, `CACHE_DATABASE_URL`. Ba kết nối PostgreSQL phải sử dụng database khác nhau. Không dùng database preview hoặc khóa thử nghiệm cho production. Kiểm tra cấu hình chỉ chạy CPU, không gọi inference provider.

Khi triển khai sau lớp HTTPS termination, chỉ nhận request qua reverse proxy tin cậy, chặn đường truy cập trực tiếp tới Rails và làm sạch `X-Forwarded-*` tại proxy. Xác nhận Rails và Solid Queue dùng cùng cấu hình secret production, và các chính sách SSL/cookie vẫn được bật.

## Đối soát tự động an toàn (chỉ phía CPU)

Solid Queue đọc `config/recurring.yml` và chạy `ReconcileTranslationDispatchesJob` mỗi năm phút trong development và production. Mỗi lượt xử lý tối đa 50 dispatch đang gửi và 50 dispatch đã được provider chấp nhận:

- Nếu POST còn ở trạng thái `submitting` quá 10 phút, đánh dấu dispatch/run là `uncertain` (`DISPATCH_OUTCOME_UNKNOWN`). **Không bao giờ xếp lại POST inference có phí.** Admin phải đối soát kết quả với provider trước khi cân nhắc gửi yêu cầu mới.
- Dispatch `accepted` quá năm phút chưa kiểm tra được chỉ được khôi phục bằng **`PollTranslationDispatchJob` / GET**, không phải POST. Vì GET có thể đánh thức hosting đang sleep, việc tự động nối lại polling **mặc định tắt**. Chỉ đặt `TRANSLATION_RECOVERY_POLLING_ENABLED=1` khi đã chấp nhận hành vi và chi phí của provider. Polling thông thường của yêu cầu dịch đã được duyệt không thay đổi.
- Mỗi lượt có giới hạn, có thể chạy lại an toàn và kiểm thử bằng mock providers mà không gọi GPU. Cần giám sát Rails và worker Solid Queue; lịch recurring chỉ chạy khi scheduler hoạt động.

## Bảo trì

Sao lưu dữ liệu ứng dụng cùng các quan hệ deployment/dispatch; bảo trì queue/cache database tùy nhu cầu retention. Kiểm tra bộ đếm rate-limit hết hạn, key rotation, quyền database và trusted proxy.

## Quy trình xử lý sự cố

1. Kiểm tra sức khỏe Rails/database/queue và sự kiện bảo mật gần nhất.
2. Phân loại lỗi xác thực, database, worker, DNS/TLS hay inference host.
3. Với request chưa chắc chắn, kiểm tra dispatch ID và provider job reference đã lưu, không gửi lặp.
4. Nếu nghi lộ credential, dùng kênh bảo mật riêng.

Xem [Khắc phục sự cố](troubleshooting.vi.md) và [Bảo mật](security.vi.md).
