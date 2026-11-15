# FreshVend — Hướng dẫn Quản trị viên

Phiên bản 1.0 · Biên soạn 15/11/2026 · Nguyễn Phạm Xuân Anh · SCRUM-240 / FV-46. Hướng dẫn theo giao diện và mã nguồn hiện có; trạng thái kiểm chứng SQL tại [Test Report](TestReport.md).

## 1. Chuẩn bị và đăng nhập

Nhờ người cài đặt cung cấp địa chỉ ứng dụng và tài khoản **Admin**. Trên máy cục bộ, địa chỉ mặc định là `http://localhost:3000/`; môi trường của nhóm có thể dùng cổng khác. Mở bằng trình duyệt, nhập tên đăng nhập và mật khẩu được cấp, bấm đăng nhập. Kiểm tra tên và vai trò hiển thị trước khi thao tác.

Người cài đặt kiểm tra `/api/health` trả `db.mode=sqlserver` và đúng tên CSDL khi sử dụng dữ liệu thật. `demo` dùng dữ liệu giả, không dùng số liệu đó để quyết toán hoặc nghiệm thu SQL. Không dùng tài khoản thử mặc định cho vận hành; không đưa mật khẩu hoặc token vào ảnh/log gửi nhóm.

Nếu sai mật khẩu, kiểm tra lại tài khoản trước khi thử tiếp: SQL khóa tài khoản sau năm lần sai. Nhờ Admin khác mở khóa; không liên tục thử mật khẩu. Khi nhận tài khoản, dùng mục **Đổi mật khẩu** trong menu tài khoản, nhập mật khẩu cũ, mật khẩu mới ít nhất tám ký tự và khác mật khẩu cũ. Đăng xuất khi kết thúc hoặc dùng chung máy.

## 2. Đọc trang Tổng quan

Chọn **Tổng quan**. Trang có doanh thu hôm nay/hôm qua, số đơn đã thanh toán, máy hoạt động, cảnh báo chưa xử lý, tỷ lệ kẹt và chuỗi lạnh; bên dưới là doanh thu 14 ngày, top sản phẩm 30 ngày và đội máy.

Doanh thu báo cáo lấy đơn `PAID`/`DISPENSED`, không cộng đơn chờ, hủy hoặc hoàn tiền. Ngày báo cáo quy đổi từ thời gian UTC sang UTC+7. Khi đối chiếu, dùng cùng ngày và cùng trạng thái đơn. Tỷ lệ kẹt hiển thị theo phần trăm; mục tiêu **dưới 2%**, đúng 2% chưa đạt. Dấu “–” hoặc thiếu dữ liệu không có nghĩa là 0% kẹt hay 100% an toàn.

Dữ liệu đội máy cập nhật qua kết nối thời gian thực. Khi hiện mất kết nối hoặc thời gian cập nhật cũ, tải lại trang và kiểm tra kết nối; không dùng số cũ để kết luận máy đang hoạt động.

## 3. Quản lý người dùng

Chọn **Người dùng** ở nhóm Quản trị. Trang có form tạo tài khoản, danh sách tài khoản và thống kê đăng nhập.

1. Nhập tên đăng nhập tối thiểu ba ký tự, họ tên, email nếu có, mật khẩu ít nhất tám ký tự.
2. Chọn vai trò Admin, Operator hoặc Kiosk theo người được cấp quyền, rồi bấm **Tạo**.
3. Kiểm tra tài khoản mới và vai trò trong danh sách. Trùng tên hoặc dữ liệu không hợp lệ sẽ báo lỗi; sửa trường tương ứng rồi gửi lại.
4. Với Operator/Kiosk, bấm **Giao máy**, tích máy cần giao hoặc bỏ tích để thu hồi. Mỗi thay đổi được lưu ngay; nếu báo lỗi, tải lại để kiểm tra trạng thái thực.
5. Bấm **Khóa** khi cần ngừng truy cập; **Mở khóa** để kích hoạt lại và xóa số lần sai. Không tự khóa tài khoản đang đăng nhập; hệ thống từ chối. Đảm bảo còn Admin khác trước khi khóa tài khoản quản trị.

Operator bị giới hạn máy theo phân công và không được đọc báo cáo tài chính. Kiosk chỉ dùng máy được giao. Không cấp Admin chỉ để vượt lỗi quyền. Bảng hoạt động đăng nhập cho biết số lần thành công, thất bại và số tài khoản theo ngày; mật khẩu không được hiển thị trong nhật ký.

**Giới hạn hiện tại:** trang này tải danh sách máy để giao máy. Trên bản SQL đã kiểm tra 15/11, thiếu view IoT khiến tải máy lỗi, dù API danh sách người dùng và thống kê đăng nhập đã đạt smoke test. Báo người phụ trách IoT; không coi màn hình trống là không có tài khoản.

## 4. Đội máy, ngưỡng và cảnh báo

Chọn **Máy & chuỗi lạnh** để xem trạng thái, nhiệt độ, ngưỡng, cửa và thời điểm tín hiệu cuối. Bấm thẻ máy để xem chi tiết và đồ thị 24 giờ. Không có bản đọc không đồng nghĩa nhiệt độ nằm trong ngưỡng.

Để cấu hình ngưỡng, mở chi tiết máy, tìm **Ngưỡng cảnh báo & thông điệp hiển thị**:

1. Nhập ngưỡng thấp/cao (mặc định 2–8°C), thời gian cửa mở tối đa, số lần vượt liên tiếp.
2. Nhập thông điệp khi suy giảm làm lạnh để khách biết tình trạng máy.
3. Bấm **Lưu ngưỡng**, mở lại chi tiết để xác nhận giá trị được lưu. Nếu báo lỗi, kiểm tra máy tồn tại và ngưỡng thấp nhỏ hơn ngưỡng cao; nhờ người phụ trách kiểm tra nếu lỗi tiếp diễn.

Không nới ngưỡng để che tình trạng quá nhiệt. Với máy lỗi, chỉ dùng **Xóa trạng thái lỗi → ACTIVE** sau khi người vận hành đã xử lý nguyên nhân và ghi chú. Nhận tín hiệu trở lại không tự chứng minh máy an toàn.

Chọn **Cảnh báo**, lọc mức độ, đọc máy/nội dung/thời gian. Bấm **Nhận xử lý** khi bắt đầu; **Đã xử lý** sau khi xác minh thực tế. Việc nhận cảnh báo không có nghĩa nguyên nhân đã được khắc phục.

**Giới hạn bản đang kiểm tra:** API máy, telemetry và cảnh báo đang lỗi vì thiếu view/TVF IoT. Các ca mô phỏng quá nhiệt, mở cửa và kết nối lại chưa đạt. Chưa dùng hệ thống này để xác nhận an toàn thực phẩm trong vận hành thực; xem lỗi cụ thể trong Test Report.

## 5. Xem báo cáo

Chọn **Báo cáo**:

1. Chọn **Từ ngày**, **Đến ngày** với từ ngày không sau đến ngày; chọn **Năm** cho tăng trưởng.
2. Bấm **Xem báo cáo**. Đọc doanh thu tháng, lũy kế và tăng trưởng; bảng địa điểm cho biết số máy, đơn, lượng và doanh thu.
3. Bảng **Giờ cao điểm** đếm số đơn theo giờ/thứ; dùng để lên lịch tiếp hàng. Đây là số đơn, không phải doanh thu theo giờ.
4. Đọc **Sản phẩm bán chạy theo địa điểm**: cùng doanh thu có thể đồng hạng. Không cộng thứ hạng của các địa điểm khác nhau.
5. Đọc **Tuân thủ chuỗi lạnh** cùng thời lượng đã quan sát. Bảng ranking và cold-chain được tải riêng; bộ lọc ngày hiện chỉ truyền cho báo cáo địa điểm/giờ cao điểm, năm chỉ áp cho tăng trưởng.

Tiêu đề giao diện hiện ghi “chuỗi lạnh 30 ngày”, nhưng view SQL tổng hợp toàn bộ hourly hiện có, không nhận bộ lọc ngày. Không hiểu bộ lọc trên form là đã lọc cold-chain/ranking. Các vấn đề số phút ngoài ngưỡng, backfill và múi giờ IoT vẫn cần chủ module xử lý. Nếu cần số liệu kỳ cụ thể cho hồ sơ, nhờ người phụ trách xuất đúng phạm vi sau khi xác minh.

## 6. Xuất CSV

Trên trang Báo cáo, chọn khoảng ngày rồi bấm **Xuất số liệu**. Trình duyệt tải file `freshvend_sales_<từ>_<đến>.csv`. Kiểm tra tên/khoảng ngày, mở file và đối chiếu vài dòng với đơn tương ứng trước khi gửi. Nếu Excel đọc tiếng Việt sai, dùng **Data → From Text/CSV**, chọn UTF-8.

Nếu lỗi 403, kiểm tra đang dùng tài khoản Admin; không gửi token để nhờ người khác xuất hộ. Nếu lỗi 500 hoặc không tải được file, lưu thời gian và thông báo lỗi rồi gửi người phụ trách. Log SQL PENDING chỉ ghi nhận yêu cầu, không chứng minh file đã tạo hoặc đã tải thành công.

Giao diện hiện có nút CSV. PDF ứng dụng chưa được nghiệm thu; không có hướng dẫn nút PDF giả. File CSV mở bằng Excel và xác nhận trạng thái export hoàn tất chưa được chạy trong đợt kiểm tra 15/11.

## 7. Kiểm thử, sao lưu và hỗ trợ

Trang **Kiểm thử** có thể ghi dữ liệu và chạy nhiều procedure; chỉ dùng trên CSDL QA được người cài đặt xác nhận. Đọc từng trạng thái PASS/FAIL/BLOCKED. Kết quả demo được ghi BLOCKED, không phải bằng chứng SQL thành công. Không bấm chạy suite trên dữ liệu kinh doanh.

Sao lưu/khôi phục do người quản trị CSDL thực hiện theo [Backup_RunAll](Backup_RunAll.md) và [Security_Demo](Security_Demo.md). Không chạy restore trong màn hình nghiệp vụ hoặc ghi đè CSDL để thử. Khi xóa nhầm, dừng thao tác liên quan và báo DBA sớm để giữ chuỗi log; cung cấp tên CSDL, thời điểm và thao tác đã làm.

| Hiện tượng | Cách xử lý |
|---|---|
| 401 hoặc phiên hết hạn | Đăng nhập lại; không chia sẻ tài khoản |
| 403 | Kiểm tra vai trò/phân công; nhờ Admin đúng quyền |
| Tài khoản khóa sau nhiều lần sai | Nhờ Admin khác mở khóa, đổi mật khẩu |
| Trang máy hoặc cảnh báo lỗi 500 | Gửi lỗi, thời điểm, tên trang; bản hiện tại còn thiếu đối tượng IoT |
| Báo cáo không có dòng | Kiểm tra khoảng ngày, dữ liệu paid, đúng CSDL và chế độ demo/SQL |
| Ngày/giờ lệch | Ghi ngày trên UI và chứng từ; nhóm còn cần thống nhất UTC, không tự sửa lịch sử đơn |
| FAIL/BLOCKED trong kiểm thử | Gửi mã ca và log; không đổi trạng thái thành PASS thủ công |

Khi báo lỗi, gửi bước tái hiện, kết quả mong đợi/thực tế, mã đơn/máy nếu có và thời gian. Che mật khẩu, thông tin khách hàng, token và khóa thiết bị trong ảnh. Hướng dẫn này đã đối chiếu mã UI/API và kết quả SQL; chưa có biên bản người dùng độc lập chạy toàn bộ thao tác trên máy khác.
