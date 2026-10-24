# Hiển thị setup SMC trên biểu đồ

## Mục tiêu

Chỉnh indicator `SMC.mq5` để đánh dấu các setup tiềm năng trên chart vàng
(XAUUSD). Indicator chỉ hỗ trợ quan sát; người dùng tự đánh giá và quyết định
có giao dịch hay không. Không viết EA, không tự đặt lệnh và không tự quản lý
vị thế.

## Khung thời gian

- **H1:** Swing bias.
- **M15:** BOS/CHoCH, OB, EQH/EQL và điều kiện setup.
- **M5:** nến xác nhận.
- Chỉ đánh dấu xác nhận sau khi nến liên quan đã đóng.
- Overlay cập nhật theo nến M5 mới; có thể gắn indicator lên chart timeframe
  khác. Dùng `SMC_KillZones_UTC` riêng nếu muốn hiển thị phiên giao dịch.

## Setup cần đánh dấu

### A — Đảo chiều

- **Mua:** H1 Swing bias giảm → M15 Swing CHoCH tăng → giá hồi về OB tăng
  → M5 có nến từ chối tăng.
- **Bán:** điều kiện ngược lại: H1 tăng → Swing CHoCH giảm → giá hồi về OB
  giảm → M5 có nến từ chối giảm.
- Internal CHoCH không kích hoạt Setup A; Setup C dùng Internal CHoCH M5.

### B — Tiếp diễn

- **Mua:** H1 và M15 bias tăng → M15 BOS tăng → giá hồi về OB tăng
  → M5 có nến từ chối tăng.
- **Bán:** điều kiện ngược lại với bias giảm, BOS giảm → giá hồi về OB giảm
  → M5 có nến từ chối giảm.
- Hiển thị OB làm biến thể chính. FVG, nếu bổ sung, phải có công tắc riêng
  để người dùng phân biệt.

### C — Quét thanh khoản

- **Mua:** có EQL M15 → nến M15 quét xuống dưới EQL rồi đóng lại phía trên
  → trong ba nến M5 tiếp theo xuất hiện Internal CHoCH tăng đã đóng.
- **Bán:** điều kiện ngược lại với EQH và Internal CHoCH giảm.
- Premium/Discount H1 không phải bộ lọc cho Setup C.

## Quy tắc hiển thị

- Panel cho biết mỗi setup đang chờ cấu trúc, chờ hồi vùng, chờ nến xác nhận,
  đã xác nhận hoặc hết hiệu lực. Trạng thái xác nhận chỉ là tín hiệu tham
  khảo, không phải khuyến nghị giao dịch.
- Vẽ OB của Setup A/B và mũi tên tại nến M5 xác nhận.
- Khi setup được xác nhận, vẽ ba đường giá dễ phân biệt: Entry là giá đóng
  cửa nến xác nhận M5; SL nằm ngoài OB (A/B) hoặc râu quét (C), thêm đệm
  0,1 ATR M15; TP là mức 2R tính từ Entry và SL. Các mức được vẽ bằng đường
  ngang toàn biểu đồ, có nhãn setup và giá, và giữ lại đến khi có tín hiệu
  xác nhận mới hoặc setup bị tắt. Đây là mức tham khảo; người dùng tự quyết
  định giao dịch và xác định giá/khối lượng cuối cùng.
- OB chỉ được xem là còn hiệu lực khi chưa có nến đóng xuyên qua biên xa và
  chiều rộng không quá 1,5 ATR(14) M15.
- Không lọc Setup A/B/C theo Premium/Discount; các vùng này nếu được bật trên
  chart chỉ dùng để tham khảo trực quan.
- Nến từ chối M5: thân nến cùng hướng setup, đóng cửa bật khỏi vùng; râu phía
  vùng ít nhất 0,5 lần thân.
- Có thể bật/tắt overlay và từng setup A/B/C; lịch sử quét MTF mặc định là
  1000 nến, sự kiện cấu trúc quá 96 nến M15 sẽ hết hiệu lực.

## Ngoài phạm vi

- Không tự vào lệnh hoặc sửa/đóng lệnh.
- Không áp dụng tự động giới hạn rủi ro, số lệnh, spread hay bộ lọc tin.
- Các mức SL/TP hiển thị chỉ để tham khảo; quyết định giao dịch thuộc về
  người dùng.
