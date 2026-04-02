--Create user FK_Advisor_AppUser
--For Login APILogin;

--Grant Execute to APIUser;


--python -m venv .venv

--.venv\Scripts\activate

--pip install pyodbc fastapi python-dotenv uvicorn

/*--1
select *
from Section as S
inner join Course as C on S.CourseID = C.CourseID
where SemesterYear = 2026 and SectionSemester = 'Spring';
--2 What are the prerequisites for a specific, course (optional entry)?
select *
from CoursePrerequisite as CP
inner join Course as C on CP.PrerequisiteID = C.CourseID
where CP.CourseID = @CourseID;

--3 Has a specific student completed the prerequisites for a specific course?
select *
from RegistrationSection as R
inner join Section as S on R.SectionID = S.SectionID
inner join Course as C on S.CourseID = C.CourseID
where R.StudentID = @StudentID and C.CourseID = @CourseID and R.EnrollmentStatus = 'Completed';
*/


IF OBJECT_ID('procGetCourseSectionsForSpecifiedCourse') IS Not NULL
drop procedure procGetCourseSectionsForSpecifiedCourse;

IF OBJECT_ID('fnGetSemesterFromMonth') IS Not NULL
Drop function fnGetSemesterFromMonth;

IF OBJECT_ID('fnGetCoursePrerequisites') IS Not NULL
Drop function fnGetCoursePrerequisites;

IF OBJECT_ID('fnGetStudentCourseHistory') IS Not NULL
Drop function fnGetStudentCourseHistory;

If OBJECT_ID('fnGetGradePointsFromLetterGrade') IS Not NULL
Drop function fnGetGradePointsFromLetterGrade;

If OBJECT_ID('trgDecreaseSectionSeats') IS Not NULL
Drop trigger trgDecreaseSectionSeats;

If OBJECT_ID('procValidateUser') IS Not NULL
Drop procedure procValidateUser;

IF OBJECT_ID('procHasStudentMetPrerequisitesForCourse') IS Not NULL
Drop procedure procHasStudentMetPrerequisitesForCourse;

GO
-- scalar function to get a semester base on month number
create or alter function dbo.fnGetSemesterFromMonth()
returns nvarchar(20)
AS
BEGIN
    declare @MonthNumber int = month(getdate());
    declare @Semester nvarchar(20);

    if @MonthNumber in (1, 2, 3, 4, 5)
        set @Semester = N'Spring';
    else if @MonthNumber in (6, 7)
        set @Semester = N'Summer';
    else
        set @Semester = N'Fall';

    return @Semester;
END;

-- select dbo.GetSemesterFromMonth() as CurrentSemester;

go

create or alter procedure procGetCourseSectionsForSpecifiedCourse
(
    @SubjectCode nvarchar(10) = null, -- parameters are for input from the user
    @CourseNumber nvarchar(10) = null -- optional parameters, so input from user is not required
)
AS
begin
    select
        C.SubjectCode, 
        C.CourseNumber, 
        C.Title, 
        S.SectionID, 
        S.CRN, 
        S.SectionNumber, 
        S.SectionSemester, 
        S.SectionYear, 
        S.RemainingOpenings,
        I.FirstName + ' ' + I.LastName AS InstructorName
    from Section S  
        inner join Course C on S.CourseID = C.CourseID
        inner join Instructor I on S.InstructorID = I.InstructorID
    where S.SectionSemester = dbo.fnGetSemesterFromMonth()
    and S.SectionYear = Year(GetDate())
    and C.SubjectCode = ISNULL(@SubjectCode, C.SubjectCode)
    and C.CourseNumber = ISNULL(@CourseNumber, C.CourseNumber)

end;

/*
execute procGetCourseSectionsForSpecifiedCourse
    @SubjectCode = 'MIST',
    @CourseNumber = '460';
*/

go

--drop function dbo.GetSemesterFromMonth



-- 2. What are the prerequisites for a specific course (optional entry)?

GO

CREATE OR ALTER PROCEDURE procGetCoursePrerequisites
(
    @SubjectCode  VARCHAR(30) = NULL,
    @CourseNumber VARCHAR(30) = NULL
)
AS
BEGIN
    IF (@SubjectCode IS NULL AND @CourseNumber IS NOT NULL)
    BEGIN
        RAISERROR('Both @SubjectCode and @CourseNumber must be provided together, or both left NULL.', 16, 1); --I used AI to help me solve this edge case. 
        RETURN;
    END;
    SELECT
        MainCourse.Title 'MainCourseTitle', MainCourse.SubjectCode 'MainCourseSubjectCode', MainCourse.CourseNumber 'MainCourseNumber',
        prereq.Title 'PrerequisiteTitle', prereq.SubjectCode 'PrerequisiteSubjectCode', prereq.CourseNumber 'PrerequisiteCourseNumber', 
        CP.MinGradeRequired 'MinGradeRequired'
            FROM CoursePrerequisite CP
        JOIN Course MainCourse ON CP.CourseID = MainCourse.CourseID
        JOIN Course prereq ON CP.PrerequisiteID = prereq.CourseID
    WHERE
        --(@SubjectCode IS NULL OR c.SubjectCode = @SubjectCode)
        MainCourse.SubjectCode = IsNull(@SubjectCode, MainCourse.SubjectCode)
        AND MainCourse.CourseNumber = IsNull(@CourseNumber, MainCourse.CourseNumber);
END;

--EXEC procGetCoursePrerequisites @SubjectCode = 'MIST', @CourseNumber = '460';

-- Use to a table-valued function instead of a stored procedure if you want to use it in a join or subquery.

go

CREATE OR ALTER function fnGetCoursePrerequisites
(
    @SubjectCode  VARCHAR(30) = NULL,
    @CourseNumber VARCHAR(30)
)
returns @Prerequisites table
(
    Title nvarchar(100),
    SubjectCode nvarchar(10),
    CourseNumber nvarchar(10),
    MinGradeRequired nchar(2)
)
AS
BEGIN
    insert into @Prerequisites
    (Title, SubjectCode, CourseNumber, MinGradeRequired)
    SELECT
        prereq.Title, prereq.SubjectCode, prereq.CourseNumber, CP.MinGradeRequired
            FROM CoursePrerequisite CP
        JOIN Course MainCourse ON CP.CourseID = MainCourse.CourseID
        JOIN Course prereq ON CP.PrerequisiteID = prereq.CourseID
    WHERE
        MainCourse.SubjectCode = IsNull(@SubjectCode, MainCourse.SubjectCode)
        AND MainCourse.CourseNumber = @CourseNumber;

    return;
END;

-- select * from fnGetCoursePrerequisites('MIST', '460');





-- 3. Has a specific student completed the prerequisites for a specific course?

-- Find all the courses that specified student has taken
GO

create or alter function fnGetStudentCourseHistory
(
    @StudentID int
)
returns @CourseHistory table
(
    SubjectCode nvarchar(10),
    CourseNumber nvarchar(10),
    Grade nchar(2)
)
AS
BEGIN
    insert into @CourseHistory
    (SubjectCode, CourseNumber, Grade)
    select 
        C.SubjectCode, 
        C.CourseNumber, 
        RS.LetterGrade
    from Registration R
        join RegistrationSection RS on R.RegistrationID = RS.RegistrationID
        join Section S on RS.SectionID = S.SectionID
        join Course C on S.CourseID = C.CourseID
    where R.StudentID = @StudentID;

    return;
END;
-- select * from fnGetStudentCourseHistory(3);

-- Encapsulate logic inside a stored procedure that 
-- checks if the student has met the prerequisites for a course.
go


create or alter function fnGradePointsFromLetterGrade
(
	@LetterGrade nchar(2)
)
returns int
as
begin
	declare @GradePoints int;
	
	set @GradePoints = case @LetterGrade
		when 'A' then 4
		when 'B' then 3
		when 'C' then 2
		when 'D' then 1
		else 0
	end;

	return @GradePoints;
end;

GO

create or alter function fnGradePointsFromLetterGrade
(
	@LetterGrade nchar(2)
)
returns int
as
begin
	declare @GradePoints int;
	
	set @GradePoints = case @LetterGrade
		when 'A' then 4
		when 'B' then 3
		when 'C' then 2
		when 'D' then 1
		else 0
	end;

	return @GradePoints;
end;

-- select dbo.fnGradePointsFromLetterGrade('A') as GradePoints;
-- select dbo.fnGradePointsFromLetterGrade(null) as GradePoints;

go

create or alter TRIGGER trgDecreaseSectionSeats
ON RegistrationSection
AFTER INSERT -- triggering event
AS
BEGIN -- trigger action -- logic to execute when the trigger is fired
    -- Decrease the RemainingOpenings in the Section table by 1 for the corresponding SectionID
    UPDATE Section
    SET RemainingOpenings = RemainingOpenings - 1
    FROM Section S
    JOIN inserted I ON S.SectionID = I.SectionID;
END;

go

create or alter procedure procEnrollStudentInSection
(
    @RegistrationID int,
    @SectionID int
)
as
begin
    insert into RegistrationSection (RegistrationID, SectionID)
    values (@RegistrationID, @SectionID); -- this should trigger the decrease in RemainingOpenings for SectionID = 1
end;
-- EXEC procEnrollStudentInSection @RegistrationID = 1, @SectionID = 1;

select *
from Registration;

-- 1. Create a stored procedure to register a student (procRegisterStudent)
-- 2. Insert Registration record for student 3 spring 2026
-- 3. Enroll student in a section of MIST 460 (procEnrollStudentInSection)


/*

select * from fnGetCoursePrerequisites('MIST', '460') as Prerequisites
join fnGetStudentCourseHistory(1) as History
    on Prerequisites.SubjectCode = History.SubjectCode
    and Prerequisites.CourseNumber = History.CourseNumber

*/

go

CREATE OR ALTER PROCEDURE procHasStudentMetPrerequisitesForCourse
    @StudentID    INT,
    @SubjectCode  VARCHAR(30),
    @CourseNumber VARCHAR(30)
AS
BEGIN

/*
    SELECT Prerequisites.SubjectCode, Prerequisites.CourseNumber, Prerequisites.MinGradeRequired,
    History.Grade
    FROM fnGetCoursePrerequisites(@SubjectCode, @CourseNumber) AS Prerequisites
        left join fnGetStudentCourseHistory(@StudentID) AS History
        ON Prerequisites.SubjectCode = History.SubjectCode
        AND Prerequisites.CourseNumber = History.CourseNumber
        AND dbo.fnGradePointsFromLetterGrade(History.Grade) 
            >= dbo.fnGradePointsFromLetterGrade(Prerequisites.MinGradeRequired);
*/

-- Subqueries - IN, NOT IN, EXISTS, NOT EXISTS
-- IN non-correlated subquery - returns all the prerequisites for the course
-- EXIST correlated subquery - checks if there is a record in the student's course history that matches the prerequisite and has a grade that meets the minimum requirement
    
    SELECT Prerequisites.SubjectCode, Prerequisites.CourseNumber, 
        Prerequisites.MinGradeRequired as 'MinimumGradeRequired', 
        IsNull(CAST(History.Grade AS NVARCHAR(20)), 'Not Completed') as 'StudentGrade'
    FROM fnGetCoursePrerequisites(@SubjectCode, @CourseNumber) AS Prerequisites
        LEFT JOIN fnGetStudentCourseHistory(@StudentID) AS History
            ON Prerequisites.SubjectCode = History.SubjectCode
            AND Prerequisites.CourseNumber = History.CourseNumber
    WHERE NOT EXISTS (
        SELECT 1
        FROM fnGetStudentCourseHistory(@StudentID) AS History
        WHERE Prerequisites.SubjectCode = History.SubjectCode
        AND Prerequisites.CourseNumber = History.CourseNumber
        AND dbo.fnGradePointsFromLetterGrade(History.Grade) 
            >= dbo.fnGradePointsFromLetterGrade(Prerequisites.MinGradeRequired)
    );


END;
GO

--EXEC procHasStudentMetPrerequisitesForCourse @StudentID = 2, @SubjectCode = 'MIST', @CourseNumber = '460';
--EXEC procHasStudentMetPrerequisitesForCourse @StudentID = 1, @SubjectCode = 'MIST', @CourseNumber = '460';
--EXEC procHasStudentMetPrerequisitesForCourse @StudentID = 3, @SubjectCode = 'MIST', @CourseNumber = '460';

go

create or alter procedure procValidateUser
(@username nvarchar(320), @password nvarchar(100))
as
begin
	select AppUserID, Firstname + ' ' + Lastname as Fullname
	from AppUser
	where Email = @username and
		PasswordHash = CONVERT(VARBINARY(64), @password, 1)
end;

/*
execute procValidateUser
@username = 'mjordan@wvu.edu', 
@password = '0x01';

select AppUserID, Firstname, LastName, Email, PasswordHash
from AppUser
*/