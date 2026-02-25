--1
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