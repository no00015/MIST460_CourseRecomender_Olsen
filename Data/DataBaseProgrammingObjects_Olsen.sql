go

IF OBJECT_ID('procGetCourseSectionsForSpecifiedCourse') is NOT NULL
    DROP PROCEDURE procGetCourseSectionsForSpecifiedCourse;

IF OBJECT_ID('fnGetSemesterFromMonth') is NOT NULL
    DROP FUNCTION fnGetSemesterFromMonth;

IF OBJECT_ID('procGetCoursePrerequisites') is NOT NULL
    DROP PROCEDURE procGetCoursePrerequisites;

IF OBJECT_ID('fnGetCoursePrerequisites') is NOT NULL
    DROP FUNCTION fnGetCoursePrerequisites;

IF OBJECT_ID('fnGetStudentCourseHistory') is NOT NULL
    DROP FUNCTION fnGetStudentCourseHistory;

IF OBJECT_ID('fnGradePointsFromLetterGrade') is NOT NULL
    DROP FUNCTION fnGradePointsFromLetterGrade;

IF OBJECT_ID('trgDecreaseSectionSeats') is NOT NULL
    DROP TRIGGER trgDecreaseSectionSeats;

IF OBJECT_ID('procValidateUser') is NOT NULL
    DROP PROCEDURE procValidateUser;

IF OBJECT_ID('procHasStudentMetPrerequisitesForCourse') is NOT NULL
    DROP PROCEDURE procHasStudentMetPrerequisitesForCourse;


GO

create or alter procedure procGetAllCourses
AS
BEGIN
    SELECT CourseID, CourseDescription
    FROM Course;
END;



GO

create or alter procedure procInsertChunk
(
    @CourseChunk NVARCHAR(MAX),
    @ChunkEmbedding VECTOR(1536),
    @CourseID INT
)
AS
BEGIN
    INSERT INTO Chunks (CourseChunk, ChunkEmbedding, CourseID)
    VALUES (@CourseChunk, @ChunkEmbedding, @CourseID);
END;



GO


go

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



go

create or alter procedure procGetCourseSectionsForSpecifiedCourse
(
    @SubjectCode nvarchar(10) = null, 
    @CourseNumber nvarchar(10) = null 
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



go



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
        MainCourse.SubjectCode = IsNull(@SubjectCode, MainCourse.SubjectCode)
        AND MainCourse.CourseNumber = IsNull(@CourseNumber, MainCourse.CourseNumber);
END;



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



go

create or alter TRIGGER trgDecreaseSectionSeats
ON RegistrationSection
AFTER INSERT 
AS
BEGIN 
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
    values (@RegistrationID, @SectionID); 
end;


select *
from Registration;



go

CREATE OR ALTER PROCEDURE procHasStudentMetPrerequisitesForCourse
    @StudentID    INT,
    @SubjectCode  VARCHAR(30),
    @CourseNumber VARCHAR(30)
AS
BEGIN


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

