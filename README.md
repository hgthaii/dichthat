<p align="center">
  <img src="Resources/AppIconSource.png" width="112" alt="DichThat icon">
</p>

<h1 align="center">DichThat</h1>

<p align="center">
  Dịch nhanh tiếng Anh ↔ tiếng Việt ngay tại nơi bạn đang đọc trên macOS.
</p>

<p align="center">
  <a href="README.md"><strong>Tiếng Việt</strong></a> ·
  <a href="README.en.md">English</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-000000?logo=apple&logoColor=white" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white" alt="Swift 6.0">
  <img src="https://img.shields.io/badge/translation-VI%20%E2%86%94%20EN-34C759" alt="Vietnamese and English">
  <img src="https://img.shields.io/badge/version-0.1.0-8E8E93" alt="Version 0.1.0">
  <a href="https://github.com/hgthaii/dichthat/actions/workflows/release.yml"><img src="https://github.com/hgthaii/dichthat/actions/workflows/release.yml/badge.svg" alt="CI/CD"></a>
</p>

## Giới thiệu

DichThat là ứng dụng nhỏ nằm trên menu bar của macOS. Bạn chỉ cần chọn một đoạn chữ, nhấn phím tắt và xem bản dịch ngay bên cạnh — không cần chuyển sang ứng dụng khác.

Ứng dụng tự nhận biết tiếng Anh hoặc tiếng Việt và dịch sang ngôn ngữ còn lại.

## Tính năng chính

- Dịch nhanh chữ đang chọn bằng phím tắt tuỳ chỉnh.
- Nhập từ hoặc câu trực tiếp từ menu bar.
- Hiển thị phiên âm, nghĩa, ví dụ và từ đồng nghĩa cho từ tiếng Anh.
- Phát âm nội dung bằng giọng đọc của macOS.
- Tự khởi động khi đăng nhập nếu bạn muốn.
- Giao diện gọn nhẹ, hỗ trợ cả Light Mode và Dark Mode.

## Cách sử dụng

1. Mở DichThat và cấp quyền **Accessibility** theo hướng dẫn trong Settings.
2. Chọn chữ tiếng Anh hoặc tiếng Việt trong ứng dụng bất kỳ.
3. Nhấn phím tắt mặc định `⌃⌥T`.
4. Bản dịch sẽ xuất hiện cạnh đoạn chữ vừa chọn.

Bạn cũng có thể click icon DichThat trên menu bar rồi nhập nội dung cần dịch.

## Quyền riêng tư

- DichThat không lưu lịch sử dịch.
- Ứng dụng không ghi lại nội dung bạn chọn hoặc clipboard.
- Nội dung cần dịch được gửi đến dịch vụ dịch trực tuyến.
- Báo lỗi chỉ kèm thông tin hệ thống cần thiết, không kèm nội dung bạn đã dịch.

## Báo lỗi

Mở **Settings → About → Report a Bug** để tạo báo lỗi có sẵn thông tin hỗ trợ, hoặc truy cập [GitHub Issues](https://github.com/hgthaii/dichthat/issues).

## Dành cho nhà phát triển

Yêu cầu macOS 13 trở lên và Swift 6.

```bash
swift test
bash scripts/build-app.sh
bash scripts/verify-app.sh
bash scripts/build-dmg.sh
```

App nằm tại `/private/tmp/dichthat-app/DichThat.app`; DMG nằm trong `dist/`.
