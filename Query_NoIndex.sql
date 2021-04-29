-- ĐỒ ÁN THỰC HÀNH #1 - CƠ SỞ DỮ LIỆU NÂNG CAO
-- MÃ ĐỒ ÁN:	2020_CSDLNC_DA1
-- MÃ NHÓM:		2020-CSDLNC-10

-- TRUY VẤN KHÔNG INDEX
USE EmployeeMng_NoIndex
GO

-- KÍ HIỆU: 
--		EmployeePayHistory  --> emp_P
--		EmployeeDepartmentHistory --> emp_D
--		Employee --> emp
--		Department --> dep

-- Câu a : Cho danh sách lương hiện tại của các nhân viên
SELECT emp_P.BusinessEntityID, emp_P.Rate 
FROM EmployeePayHistory emp_P
WHERE EXISTS (
	SELECT emp_P1.BusinessEntityID
	FROM EmployeePayHistory emp_P1
	WHERE emp_P1.BusinessEntityID =  emp_P.BusinessEntityID 
	GROUP BY emp_P1.BusinessEntityID
	HAVING  emp_P.RateChangeDate = MAX(emp_P1.RateChangeDate)
	)
ORDER BY emp_P.BusinessEntityID ASC

-- Câu b : Cho biết tổng lương đã trả cho các nhân viên theo từng năm
-- Ngày cuối năm
CREATE FUNCTION ngaycuoinam
(
	@nam int
)
RETURNS DATETIME
AS
BEGIN
	DECLARE @ngaycuoinam DATETIME
	SET @ngaycuoinam = CAST ('12/31/'+ CAST(@nam AS VARCHAR(4)) AS DATETIME)
	RETURN @ngaycuoinam
END

-- Tìm số ngày trong 1 năm
CREATE FUNCTION fn(@year int)
RETURNS int
AS
BEGIN  
DECLARE @a int
SELECT @a =DATEPART(dy,CAST(@year AS VARCHAR(20)) +'1231')
RETURN @a
END

--Dùng CURSOR duyệt trên từng dòng để tính lương trong 1 năm
CREATE FUNCTION tinhluong
(
	@nam int
)
RETURNS money
AS 
BEGIN
	DECLARE @tongluong money = 0
	DECLARE cur_Tongluong CURSOR FOR 
	SELECT emp.BusinessEntityID,emp_P.Rate,emp_P.RateChangeDate
	FROM Employee emp, EmployeePayHistory emp_P
	WHERE emp.BusinessEntityID = emp_P.BusinessEntityID
	AND YEAR(emp_P.RateChangeDate)<=@nam
	OPEN cur_Tongluong
	DECLARE @ID int
	DECLARE @rate money
	DECLARE @ratechangedate datetime
	FETCH NEXT FROM cur_Tongluong INTO @ID,@rate,@ratechangedate
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF (YEAR(@ratechangedate) = @nam)
				SET @tongluong += datediff(day,@ratechangedate,dbo.ngaycuoinam(@nam))*8*@rate
		ELSE 
			BEGIN
				SET @tongluong+= dbo.fn(@nam) *8*@rate
			END
		FETCH NEXT FROM cur_Tongluong INTO @ID,@rate,@ratechangedate
	END
	CLOSE cur_Tongluong
	DEALLOCATE cur_Tongluong
	RETURN @tongluong
END

-- Tính lương
DECLARE @minyear int 
SELECT @minyear= MIN(YEAR(RateChangeDate))
					FROM EmployeePayHistory
DECLARE @LUONG TABLE (Nam int, Tongluong money)
WHILE @minyear <YEAR(GETDATE())
	begin
		INSERT into @luong
		VALUES (@minyear,dbo.tinhluong(@minyear))
		SET @minyear +=1
		end
SELECT*FROM @LUONG

-- Câu c : Cho danh sách nhân viên có lương cao nhất của từng phòng ban
SELECT emp_D.BusinessEntityID,emp_D.DepartmentID, MAX(emp_P.Rate) 'Rate'
FROM EmployeeDepartmentHistory emp_D, EmployeePayHistory emp_P
WHERE emp_D.BusinessEntityID=emp_P.BusinessEntityID
GROUP BY emp_D.BusinessEntityID,emp_D.DepartmentID
HAVING MAX(emp_P.Rate)>=(
	SELECT MAX(emp_P1.Rate) 
	FROM EmployeePayHistory emp_P1, EmployeeDepartmentHistory emp_D1
	WHERE emp_D1.BusinessEntityID=emp_P1.BusinessEntityID and emp_D1.DepartmentID=emp_D.DepartmentID
	)

-- Câu d : Cho danh sách các nhân viên thuộc phòng Production đã vào làm từ 5 năm trở lên
SELECT emp.BusinessEntityID, emp.NationalIDNumber, emp.LoginID, emp_D.StartDate, emp_D.EndDate
FROM Department dep LEFT JOIN EmployeeDepartmentHistory emp_D ON dep.DepartmentID = emp_D.DepartmentID
					LEFT JOIN Employee emp ON emp.BusinessEntityID = emp_D.BusinessEntityID
WHERE dep.Name ='Production' AND DATEDIFF(YEAR, emp_D.StartDate, ISNULL(emp_D.EndDate, GETDATE())) >= 5

-- Câu e : Cho danh sách các nhân viên còn làm việc tại công ty
SELECT *
FROM Employee emp
WHERE emp.CurrentFlag = 1

-- Câu f : Cho biết lịch sử công tác và mức lương cao nhất tương ứng tại vị trí công tác của nhân viên có id = 4. 
SELECT emp_P.BusinessEntityID, emp_D.DepartmentID, emp_D.ShiftID, emp_D.StartDate, emp_D.EndDate, MAX(Rate) 'MaxRate'
FROM EmployeeDepartmentHistory emp_D, EmployeePayHistory emp_P
WHERE emp_P.BusinessEntityID = emp_D.BusinessEntityID
	AND emp_P.BusinessEntityID = 4
	AND (emp_P.RateChangeDate BETWEEN emp_D.StartDate AND ISNULL(emp_D.EndDate, emp_P.RateChangeDate))
GROUP BY emp_D.DepartmentID, emp_P.BusinessEntityID, emp_D.ShiftID, emp_D.StartDate, emp_D.EndDate
