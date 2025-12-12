import Foundation

@main
struct CsvRowTests {
    static func main() throws {
        try testHeaderMatchesSpecification()
        try testSerializationOrderAndValues()
        print("CsvRowTests passed")
    }

    static func testHeaderMatchesSpecification() throws {
        let expected = "session_id,date,time,plan_name,day_label,segment_id,superset_id,ex_code,adlib,set_num,reps,time_sec,weight,unit,is_warmup,rpe,rir,tempo,rest_sec,effort_1to5,tags,notes,pr_types"
        guard CsvRow.header == expected else {
            throw Failure("Header mismatch.\nExpected: \(expected)\nActual:   \(CsvRow.header)")
        }
    }

    static func testSerializationOrderAndValues() throws {
        let date = Date(timeIntervalSince1970: 0)
        var row = CsvRow(
            sessionID: "SID",
            date: date,
            planName: "Plan",
            dayLabel: "Day A",
            segmentID: 2,
            supersetID: "SS1",
            exerciseCode: "PRESS.DB.FLAT",
            isAdlib: false,
            setNumber: 3,
            reps: "8",
            weight: "-20.5",
            unit: "lb",
            isWarmup: true,
            effort: 3
        )
        row.tags = "amrap"
        let serialized = row.serialize()
        let columns = serialized.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard columns.count == CsvRow.header.split(separator: ",").count else {
            throw Failure("Expected 24 columns, found \(columns.count)")
        }
        func assert(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            if !condition() { throw Failure(message) }
        }
        try assert(columns[0] == "SID", "session_id mismatch: \(columns)")
        try assert(columns[7] == "PRESS.DB.FLAT", "ex_code mismatch: \(columns)")
        try assert(columns[10] == "8", "reps mismatch: \(columns)")
        try assert(columns[12] == "-20.5", "weight mismatch: \(columns)")
        try assert(columns[13] == "lb", "unit mismatch: \(columns)")
        try assert(columns[19] == "3", "effort column unexpected: \(columns)")
        try assert(columns[20] == "amrap", "tags column unexpected: \(columns)")
    }

    struct Failure: Error {
        let message: String
        init(_ message: String) { self.message = message }
    }
}
