# Đề xuất thay đổi

> 🌐 Language / Ngôn ngữ: [English](PULL_REQUEST_TEMPLATE.md) | **Tiếng Việt**

## Tóm tắt

Mô tả thay đổi và mục đích.

## Phạm vi

Controller, service, migration database, quy tắc bảo mật, UI hoặc tài liệu nào bị ảnh hưởng?

## Kiểm tra

- [ ] Minitest và kiểm tra tài liệu pass trên local.
- [ ] Tài liệu EN/VI được đồng bộ.
- [ ] Không sử dụng API credential thật, secret hoặc inference có phí trong test.
- [ ] Thay đổi có phạm vi rõ ràng và dễ review.

## Tác động bảo mật và chi phí

Giải thích thay đổi ở authentication, authorization, token, rate limit, endpoint, queue hoặc request provider có thể phát sinh phí.

## Bằng chứng

Cung cấp commit SHA chính xác và kết quả test đã ẩn thông tin nhạy cảm. Không tuyên bố đã nghiệm thu GPU hoặc production nếu thiếu bằng chứng độc lập.
