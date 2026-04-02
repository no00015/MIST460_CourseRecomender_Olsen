from get_db_connection import get_db_connection

def get_course_sections_for_specified_course(
    subject_code: str = None,
    course_number: str = None,
):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("{CALL procGetCourseSectionsForSpecifiedCourse(?,?)}", (subject_code, course_number))
    rows = cursor.fetchall()
    conn.close()

    results = []
    for row in rows:
        results.append({
            "SubjectCode": row.SubjectCode,
            "CourseNumber": row.CourseNumber,
            "SectionSemester": row.SectionSemester,
            "SectionYear": row.SectionYear,
            "RemainingOpenings": row.RemainingOpenings,
            "SectionNumber": row.SectionNumber,
            "InstructorName": row.InstructorName
        })
    return {"data": results}