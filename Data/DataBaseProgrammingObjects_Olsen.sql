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
where SemesterYear = 2026 and SectionSemester = Spring;
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


create or alter procedure GetCourseSectionsForSpecifiedCourse
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

GO

create or alter function fnGetStudentCourseHistory
(
    @StudentID INT,
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
    from Registration RADIANS
        join RegistrationSection RS on R.RegistrationID = RS.RegistrationID
AS
BEGIN
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
        END

Create or ALTER function fnGetCoursePrerequisites
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
    PrerequisitesGrade NVARCHAR(2)
)
as 
BEGIN
    insert into @prerequisites
    (Title, SubjectCode, CourseNumber)
    select 
        prereq.Title, prereq.SubjectCode, prereq.CourseNumber
    from CoursePrerequisite as CP
    join Course MainCourse on CP.CourseID = MainCourse.CourseID
    join Course prereq on CP.PrerequisiteID = prereq.CourseID
where 
    MainCourse.SubjectCode = ISNULL(@SubjectCode, MainCourse.SubjectCode) and MainCourse.CourseNumber = ISNULL(@CourseNumber, MainCourse.CourseNumber);
END;

--Links together tables to compare if our grade in a class is greater than the minimum grade required
Select Prerequisetes.SubjectCode, Prerequisetites.CourseNumber, Prerequisites.MinGradeRequired
From fnGetCoursePrerequisites(@SubjectCode, @CourseNumber) as Prerequisites
Where not exists (
    Select 1
    From fnGetStudentCourseHistory(@StudentID) as History
    Where Prerequisites.SubjectCode = History.SubjectCode
    and Prerequisites.CourseNumber = History.CourseNumber
    and dbo.fnGradePointsFromLetterGrade(History.Grade) >= dbo.fnGradePointsFromLetterGrade(Prerequisites.MinGradeRequired)
);