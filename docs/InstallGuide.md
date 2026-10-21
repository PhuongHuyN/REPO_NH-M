# InstallGuide — Hướng dẫn Cài đặt Chi tiết

> **Dự án:** FreshVend  
> **Phiên bản:** 0.1 (draft)  

---

## Yêu cầu môi trường

- SQL Server 2019+ (Developer / Express / Standard)
- SSMS 18+ hoặc Azure Data Studio
- Quyền `sysadmin` hoặc `dbcreator`

## Các bước cài đặt

```
1. Kết nối SQL Server bằng SSMS
2. Mở file sql/00_database.sql → Execute (F5)
3. Mở file sql/01_schemas.sql  → Execute
4. Chạy lần lượt 02_tables_auth.sql → _inventory → _sales → _iot → _audit
5. Chạy sql/03_foreign_keys.sql
6. Chạy sql/04_indexes.sql (nếu có)
7. Chạy sql/09_seed_data.sql để nạp dữ liệu mẫu
```

## Kiểm tra sau cài đặt

```sql
USE FreshVendDB;
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
ORDER BY TABLE_SCHEMA, TABLE_NAME;
```

Kết quả kỳ vọng: 20+ bảng thuộc 5 schema (auth, inventory, sales, iot, audit, report).
