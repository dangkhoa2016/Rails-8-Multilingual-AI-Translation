# Vòng đời dịch thuật

> 🌐 Language / Ngôn ngữ: **Tiếng Việt** | [English](translation-workflow.md)

## Gửi yêu cầu

1. Quản trị viên nhập văn bản nguồn, nhãn ngôn ngữ nguồn/đích và tùy chọn giữ định dạng.
2. Chọn từ một đến bốn model **đã cấu hình**. Các trường ngôn ngữ không dùng whitelist hard-code.
3. Bắt buộc xác nhận chi phí; chọn nhiều model có thể phát sinh nhiều lần chạy tính phí.
4. Planner lưu bản ghi yêu cầu và từng dispatch theo model với idempotency key trước khi gọi API.
5. Solid Queue gửi yêu cầu tới provider và lưu trạng thái accepted, completed hoặc uncertain.

## So sánh kết quả

Trang kết quả hiển thị một thẻ cho mỗi model đã chọn, với trạng thái và bản dịch riêng. Admin có thể xem lịch sử, đánh dấu kết quả ưa thích và xem lỗi từng model. Cặp ngôn ngữ không hỗ trợ được thông báo khi provider trả `UNSUPPORTED_LANGUAGE_PAIR`; Rails không tự nhận biết chính xác toàn bộ danh mục ngôn ngữ được từng model hỗ trợ.

## Thông số hiệu năng từ provider

Adapter Translation Gateway V1 giữ các field `usage`, `timings`, `resources` tùy chọn theo từng attempt từ GET có xác thực. Chi tiết kỹ thuật hiển thị token, thời gian chờ/inference, mẫu CPU/GPU nếu có. Mẫu GPU không phải mức đỉnh hoặc trung bình; không có số đo không có nghĩa bằng 0. Thời gian dispatch của Rails bao gồm polling nên không được đánh đồng với thời gian inference. Snapshot đã mã hóa chỉ lưu field số nằm trong allowlist.

## Retry và đối soát

Mở lịch sử hoặc trang so sánh không được gửi inference mới. Polling job đã nhận sử dụng GET. Nếu POST có phí có thể đã đến provider nhưng mất phản hồi, trạng thái vẫn là chưa chắc chắn cho tới khi đối soát rõ ràng; tự retry có thể gây tính phí trùng.

## Giới hạn hiện tại

Ứng dụng chưa có giao diện quản lý attempts/đối soát thủ công đầy đủ hoặc dịch tài liệu hàng loạt. Gateway v1 giới hạn 1.000 Unicode code points cho đầu vào; tách văn bản dài thành các đoạn ngữ nghĩa chưa phải pipeline tài liệu tự động đã triển khai. Xem [Giới hạn](limitations.vi.md).
