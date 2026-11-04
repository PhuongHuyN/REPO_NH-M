# Sử dụng báo cáo TV5

Cài đặt theo README.md. Seed cung cấp dữ liệu SQL lịch sử cố định 06/08/2026–03/11/2026; không tạo mật khẩu đăng nhập ứng dụng thật. Tài khoản ứng dụng và cấu hình quyền do chủ module auth cấp.

## Doanh thu

```sql
EXEC report.sp_DashboardKpi @AsOf='20261103';
EXEC report.sp_RevenueGrowth @Year=2026;
EXEC report.sp_PeakHours @From='20260806',@To='20261103';
SELECT * FROM report.fn_RevenueByLocation('20260806','20261103');
SELECT * FROM report.vw_ProductRanking ORDER BY LocationId,RankInLocation;
```

Revenue tính chi tiết đơn paid theo ngày UTC+7, không bao gồm pending/cancelled/refunded. Dashboard trả 3 tập kết quả: KPI, 14 ngày, top 5 sản phẩm. Máy hoạt động có Status=online. Xếp hạng RANK theo địa điểm, đồng doanh thu đồng hạng. LocationType/District hiện chưa có metadata trong schema nền, trả NULL.

## Xuất dữ liệu

```sql
DECLARE @UserId INT=(SELECT UserId FROM auth.[User] WHERE Username=N'admin01');
EXEC report.sp_ExportSales @From='20260806',@To='20261103',@UserId=@UserId,@FileFormat=N'CSV';
```

Procedure trả các dòng xuất và ghi log PENDING với tham số JSON. FileFormat nhận CSV hoặc PDF để xác định yêu cầu; SQL không trực tiếp tạo file. Ứng dụng phải tạo file, cập nhật SUCCESS/FAILED và kiểm tra quyền. Route CSV hiện có trong ứng dụng; User Story và ca kiểm thử PDF nằm trong TestPlan, chưa coi là tính năng PDF đã nghiệm thu.

## Đội máy và chuỗi lạnh

```sql
EXEC report.sp_RefreshTelemetryHourly @From='20261101',@To='20261103';
SELECT * FROM report.vw_ColdChainCompliance;
SELECT MachineId,report.fn_DispenseFailureRate(MachineId) FailureRate FROM inventory.Machine;
```

Refresh telemetry dùng ngày UTC, cần chạy sau ingest/sửa/xóa raw telemetry. Tích hợp lịch định kỳ với owner IoT; seed đã tự gọi. View compliance tính toàn lịch sử đã tổng hợp. Kiểm tra MonitoredSeconds cùng tỷ lệ; khoảng không được quan sát không tự tính là tuân thủ. Không dữ liệu trả NULL. FailureRate là tỷ lệ 0..1; nhân 100 để hiển thị phần trăm, <0.02 mới đạt mục tiêu kẹt dưới 2%.

## Tổng hợp và kiểm thử

```sql
EXEC report.sp_RefreshDailySummary @Date='20260806',@ToDate='20261103';
EXEC report.sp_RunAllTests;
SELECT * FROM report.vw_LatestTestRun ORDER BY TestId;
```

Runner ghi dữ liệu và phục vụ kiểm thử, chỉ chạy trên CSDL test. Bộ SQL kiểm tra 21 ca procedure (7 procedure × 3), thêm oracle và ca biên tại tests/. Không dùng PASS từ mock ứng dụng làm bằng chứng SQL Server.
