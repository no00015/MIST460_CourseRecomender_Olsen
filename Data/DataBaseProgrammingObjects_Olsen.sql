--1
select *
from Section
where SemesterYear = 2026 and SectionSemester = Spring;
--2 What are the prerequisites for a specific, course (optional entry)?
select *
from CoursePrerequisite;