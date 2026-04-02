Create user FK_Advisor_AppUser
For Login APILogin;

Grant Execute to APIUser;


python -m venv .venv

.venv\Scripts\activate

pip install pyodbc fastapi python-dotenv uvicorn

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
create or alter function dbo.fnGetSemesterFromMonth()
returns nvarchar(20)
AS BEGIN
    DECLARE @CurrentMonth INT = MONTH(GETDATE());
    DECLARE @Semester NVARCHAR(20);

    IF @CurrentMonth IN (1, 2, 3, 4, 5)
        SET @Semester = 'Spring';
    ELSE IF @CurrentMonth IN (6, 7)
        SET @Semester = 'Summer';
    ELSE
        SET @Semester = 'Fall';

    RETURN @Semester;
END;

GO

create or alter procedure procGetCourseSectionsForSpecifiedCourse
(
    @SubjectCode nvarchar(15) = null,
    @CourseNumber nvarchar(15) = null
)
As BEGIN

select C.SubjectCode, C.CourseNumber, C.Title, S.SectionID, S.SectionSemester, S.SectionYear, S.CRN, S.RemainingOpenings, S.SectionNumber, I.FirstName + '' + I.LastName as InstructorName
from Section as S
inner join Course as C on S.CourseID = C.CourseID
inner join Instructor as I on S.InstructorID = I.InstructorID
where S.SectionSemester = dbo.fnGetSemesterFromMonth()
and S.SectionYear = Year(GetDate())
and C.SubjectCode = ISNULL(@SubjectCode, C.SubjectCode)
and C.CourseNumber = ISNULL(@CourseNumber, C.CourseNumber);

return;
END;
-- execute procGetCourseSectionsForSpecifiedCourse
GO

create or alter procedure procGetCoursePrerequisites
    @SubjectCode NVARCHAR(30) = NULL,
    @CourseNumber NVARCHAR(30) = NULL
AS
BEGIN
    If (@SubjectCode is Null and @CourseNumber is not Null)
        BEGIN
            RAISERROR('Both @SubjectCode and @CourseNumber must be provided together, or both must be omitted.');
            RETURN;
        END;
    SELECT 
        prereq.Title AS 'PrerequisiteTitle', prereq.SubjectCode AS 'PrerequisiteSubjectCode', prereq.CourseNumber AS 'PrerequisiteCourseNumber', MainCourse.Title AS 'MainCourseTitle', MainCourse.SubjectCode AS 'MainCourseSubjectCode', MainCourse.CourseNumber AS 'MainCourseNumber', CP.MinGradeRequired AS 'MinimumGradeRequired'
    FROM CoursePrerequisite AS CP
    JOIN Course MainCourse ON CP.CourseID = MainCourse.CourseID
    JOIN Course prereq ON CP.PrerequisiteID = prereq.CourseID
    WHERE 
        MainCourse.SubjectCode = ISNULL(@SubjectCode, MainCourse.SubjectCode) 
        AND MainCourse.CourseNumber = ISNULL(@CourseNumber, MainCourse.CourseNumber);
END;

GO
create or alter function fnGetCoursePrerequisites
(
    @SubjectCode NVARCHAR(30) = NULL,
    @CourseNumber NVARCHAR(30) = NULL,
    @MinimumGrade NVARCHAR(2) = NULL
)
returns @Prerequisites TABLE
(
    Title NVARCHAR(100),
    SubjectCode NVARCHAR(30),
    CourseNumber NVARCHAR(30),
    MinGradeRequired NVARCHAR(2)
)
as 
BEGIN
    insert into @prerequisites
    (Title, SubjectCode, CourseNumber, MinGradeRequired)
    select 
        prereq.Title, prereq.SubjectCode, prereq.CourseNumber, CP.MinGradeRequired
    from CoursePrerequisite as CP
    join Course MainCourse on CP.CourseID = MainCourse.CourseID
    join Course prereq on CP.PrerequisiteID = prereq.CourseID
where 
    MainCourse.SubjectCode = ISNULL(@SubjectCode, MainCourse.SubjectCode) and MainCourse.CourseNumber = @CourseNumber;
    return;
END;

GO
create or alter function fnGetStudentCourseHistory
(
    @StudentID INT
)

RETURNS @CourseHistory TABLE
(
    SubjectCode nvarchar(10),
    CourseNumber nvarchar(10),
    Grade nvarchar(2)
)
AS
BEGIN
    insert into @CourseHistory(SubjectCode, CourseNumber, Grade)
    SELECT 
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

GO
create or alter function fnGradePointsFromLetterGrade
(
    @LetterGrade NVARCHAR(2)
)
RETURNS INT
AS
BEGIN

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
create or alter trigger trgDecreaseSectionSeats
on RegistrationSection 
after INSERT
AS
BEGIN
    update Section
    set RemainingOpenings = RemainingOpenings - 1
    from Section as S
    join inserted as I on S.SectionID = I.SectionID;
    end;

GO
create procedure procEnrollStudentInSection
(
    @RegistrationID INT,
    @SectionID INT
)
as
BEGIN
insert into RegistrationSection (RegistrationID, SectionID)
values (@RegistrationID, @SectionID);
end;

select
    If (@SubjectCode IS NULL AND @CourseNumber IS NOT NULL)
        BEGIN
            RAISERROR('Both @SubjectCode and @CourseNumber must be provided together, or both must be omitted.', 16, 1);
            RETURN;
        END
        SELECT  prereq.Title, prereq.SubjectCode, prereq.CourseNumber
        from CoursePrerequisite as p
        ELSE IF (@SubjectCode IS NOT NULL AND @CourseNumber IS NULL)
        BEGIN
            RAISERROR('SubjectCode provided without CourseNumber. Please provide both or neither.', 16, 1);
            RETURN;
        END;

GO

returns @Prerequisites TABLE
(
    Title NVARCHAR(100),
    SubjectCode NVARCHAR(30),
    CourseNumber NVARCHAR(30),
    PrerequisitesGrade NVARCHAR(2)
)
as 
BEGIN
    insert into @prerequisites
    (Title, SubjectCode, CourseNumber, MinGradeRequired)
    select 
        prereq.Title, prereq.SubjectCode, prereq.CourseNumber
    from CoursePrerequisite as CP
    join Course MainCourse on CP.CourseID = MainCourse.CourseID
    join Course prereq on CP.PrerequisiteID = prereq.CourseID
where 
    MainCourse.SubjectCode = ISNULL(@SubjectCode, MainCourse.SubjectCode) and MainCourse.CourseNumber = ISNULL(@CourseNumber, MainCourse.CourseNumber);
END;

--Links together tables to compare if our grade in a class is greater than the minimum grade required
Select Prerequisites.SubjectCode, Prerequisites.CourseNumber, Prerequisites.MinGradeRequired
From fnGetCoursePrerequisites(@SubjectCode, @CourseNumber) as Prerequisites
Where not exists (
    Select 1
    From fnGetStudentCourseHistory(@StudentID) as History
    Where Prerequisites.SubjectCode = History.SubjectCode
    and Prerequisites.CourseNumber = History.CourseNumber
    and dbo.fnGradePointsFromLetterGrade(History.Grade) >= dbo.fnGradePointsFromLetterGrade(Prerequisites.MinGradeRequired)
);