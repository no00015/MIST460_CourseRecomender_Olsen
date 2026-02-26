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

GO

create or alter function fnGetStudentCourseHistory
(
    @StudentID INT,
)
RETURNS @CourseHistory TABLE
(
    SubjectCode nvarchar(10)
    CourseNumber nvarchar(10),
    Grade nchar(2)
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
    @CourseNumber NVARCHAR(30) = NULL
)
returns @Prerequisites TABLE
(
    Title NVARCHAR(100),
    SubjectCode NVARCHAR(30),
    CourseNumber NVARCHAR(30)
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