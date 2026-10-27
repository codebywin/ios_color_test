# Color Test

Ứng dụng iOS độc lập tạo nền màu và ghi lại RGB cùng thời điểm yêu cầu đổi
màu. Ứng dụng hiển thị camera trước trong khung oval, nhưng không chụp màn hình
hay lưu video.

## Build và cài đặt

Workflow GitHub Actions build gói RootHide riêng tại artifact `color-test-roothide`.
Trên thiết bị jailbreak tương thích, cài file `.deb` bằng trình quản lý gói.
Để build bằng Theos trên máy Mac:

```sh
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide
```

## Sử dụng

Cho phép truy cập camera khi được hỏi. Nếu từ chối, có thể cấp lại quyền trong
Settings; thông báo camera hiển thị trong bảng điều khiển. Chọn khoảng 250 ms,
500 ms, 1 s hoặc 2 s, sau đó nhấn **Start**. Phần nền bên ngoài bảng điều khiển
và khung camera lần lượt hiển thị đen, trắng, đỏ, lục, lam, vàng,
cyan, magenta và xám. **Stop** dừng chu kỳ; **Share CSV** chia sẻ các sự kiện
đã ghi trong phiên hiện tại. Các sự kiện sẽ mất khi đóng ứng dụng.

CSV chứa RGB mong muốn, thời điểm Unix và thời điểm monotonic tính từ lúc
khởi động máy. Đây là thời điểm ứng dụng **yêu cầu** đổi màu, không phải
thời điểm màn hình thực sự phát sáng. Lịch được điều khiển bởi display link,
nên thời gian thực tế có thể lệch do tần số màn hình và tải hệ thống.

RGB trong CSV là giá trị đầu vào, không phải kết quả đo. Hiển thị, quản lý
màu và thiết bị đọc có thể làm kết quả khác giá trị đầu vào; cần một phép đo
độc lập để tính sai lệch màu hoặc độ trễ. Các vùng bảng điều khiển, camera và
thanh hệ thống không thuộc vùng nền màu chuẩn.
