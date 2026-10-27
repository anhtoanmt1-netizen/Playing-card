# Kiểm kê tài nguyên hình ảnh tham khảo

Nguồn: tệp ZIP do chủ dự án cung cấp (thư mục tên "Khủng long"). Danh sách chi tiết, mã băm và quyết định cho từng tệp nằm ở `assets-reference/manifest.json`.

## Tóm tắt

- **17 ảnh**, đều là *bảng sticker nhiều hình trên một ảnh* (rộng ~675–736 px), không phải từng thẻ riêng lẻ.
- Tên thư mục ("Khủng long") **không khớp nội dung**: chỉ 3 ảnh là khủng long; còn lại là động vật nông trại/rừng, cây chậu kawaii, xương rồng, nấm, linh thú, cá và mèo.
- Không có thông tin tác giả, nguồn hay giấy phép đi kèm. Tên tệp cho thấy nhiều ảnh tải từ mạng xã hội/trang chia sẻ ảnh ("tải xuống (n)", "Kawaii Plant stickers", "Innova Manualidades…").
- **Kết luận: coi toàn bộ là tài liệu THAM KHẢO phong cách, không phải tài nguyên được phép phát hành.**

## Phân loại và quyết định

| Nhóm | Ảnh (theo manifest) | Phù hợp bộ thẻ | Quyết định |
|---|---|---|---|
| Động vật kawaii/nông trại | ♠️, 50+ cute animal…, tải xuống (1) | Bộ 1 Động vật, Bộ 4 Đại dương | Tham khảo phong cách |
| Khủng long | 27 Mini Cute…, Easy Drawing…35 Baby Dinosaur, tải xuống | Bộ 3 Khủng long | Tham khảo phong cách |
| Thực vật/nấm/xương rồng | Kawaii Plant stickers, Mushroom, tải xuống (2), (3) | Bộ 2 Thực vật | Tham khảo phong cách |
| Thực vật – nguồn thương mại | Innova Manualidades… | Bộ 2 | Chỉ tham khảo, nguồn là trang bán hàng |
| Linh thú giống Pokémon | tải xuống (4), (5) | Bộ 5 Huyền bí | Tham khảo ý tưởng; **không sao chép hình/bố cục nhân vật** |
| Tác phẩm nghệ sĩ riêng | tải xuống (6), (7) | Bộ 5 / Bộ 4 | **Loại** – phong cách cá nhân, có tên/thương hiệu tác giả |
| Ảnh cá vàng + mèo chibi | tải xuống (8) | Bộ 4 / Bộ 1 | Chỉ tham khảo; phần cá vàng trông như ảnh chụp |
| **Sticker Pokémon** | tải xuống (9) | – | **Loại hoàn toàn** – nhân vật có bản quyền |

## Phong cách rút ra (để vẽ hình gốc)

- Viền trắng dày kiểu sticker + bóng đổ nhẹ; nền trong suốt.
- Nhân vật tròn trịa, mắt to đen có điểm sáng, má hồng, miệng nhỏ.
- Màu phẳng pastel, đổ bóng đơn giản 1–2 tông; chi tiết nhỏ (tim, sao, lá).
- Cây chậu và nấm "có mặt cười" – dễ làm hàng loạt và dễ nhận diện.

## Kế hoạch tài nguyên cho thư viện thẻ (Giai đoạn 4)

1. **Không** cắt ảnh từ các bảng này để làm thẻ, kể cả ảnh có vẻ do AI tạo – giấy phép/quyền sở hữu không rõ.
2. Vẽ **hình minh hoạ gốc** bằng SVG theo phong cách trên, dùng hệ thống bộ phận dùng lại (thân, mắt, má, phụ kiện) để sinh nhiều nhân vật nhất quán, nhẹ cho PWA.
3. Sinh vật huyền bí là **vũ trụ nguyên bản** với tên và tạo hình riêng; không dùng tên/đặc điểm Pokémon.
4. Ánh xạ: `card_id → art_key → /images/cards/<art_key>.svg|webp`. Bảng `cards` lưu `art_key`; quản trị viên thay hình bằng cách đổi `art_key`.
5. Tối ưu: SVG nội tuyến cho thẻ đơn giản; WebP ≤ 40 KB cho thẻ phức tạp; lazy-load, không tải cả thư viện cùng lúc.
6. Nếu chủ dự án có **giấy phép bằng văn bản** cho một số ảnh, ghi nguồn và giấy phép vào `manifest.json` trước khi dùng.

## Việc cần chủ dự án xác nhận

- Nguồn gốc và quyền sử dụng của từng ảnh (đặc biệt nếu muốn dùng nguyên bản).
- Có muốn thuê hoạ sĩ để vẽ bộ thẻ cao cấp (Huyền thoại → Tối cao) hay không; SVG tự sinh phù hợp cho bản đầu nhưng khó đạt chất lượng minh hoạ chuyên nghiệp.
