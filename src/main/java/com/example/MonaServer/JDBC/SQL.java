package com.example.MonaServer.JDBC;

public class SQL {

    public String updateById() {return "UPDATE $ SET id=? WHERE id=?";}

    public String selectEntryBetween() {
        return "SELECT * FROM $ WHERE date <= ? AND date >= ? ORDER BY row_id DESC";
    }

    public String selectAllEntry() {
        return "SELECT * FROM $ ORDER BY row_id DESC";
    }

    public String selectEntryDate1() {
        return "SELECT * FROM $ WHERE date <= ? ORDER BY row_id DESC";
    }

    public String selectFirst(int limit) {return "SELECT * FROM $ WHERE date >= ? ORDER BY row_id DESC FETCH NEXT " + limit + " ROW ONLY";}

    public String selectEntryDate2() {
        return "SELECT * FROM $ WHERE date >= ? ORDER BY row_id DESC";
    }

    public String insertEntry() {
        return "INSERT INTO $ (row_id, date, value) VALUES (DEFAULT, ?,?)";
    }

    public String deleteEntryBetween() {
        return "DELETE FROM $ WHERE date <= ? AND date >= ?";
    }

    public String deleteAllEntry() {
        return "DELETE FROM $";
    }

    public String deleteEntryDate1() {
        return "DELETE FROM $ WHERE date <= ?";
    }

    public String deleteEntryDate2() {
        return "DELETE FROM $ WHERE date >= ?";
    }

    public String createEntryTable() {
        return "CREATE TABLE $ (row_id SERIAL PRIMARY KEY, date TIMESTAMPTZ, value NUMERIC(10,2))";
    }

    public String deleteEntryTable() {
        return "DROP TABLE $";
    }

    public String selectDisplay() {
        return "WITH a AS (select date, row_id, AVG(value) over (partition by " +
                "(round(extract(epoch from date) / ? ) * ?) " +
                "order by row_id rows between unbounded preceding and current row " +
                ") as value, row_number() over ( " +
                "partition by " +
                "(round(extract(epoch from date) / ?) * ?) " +
                "order by row_id desc " +
                "rows between unbounded preceding and current row) as row " +
                "from $ where date <= ? and date >= ?) " +
                "select date, row_id, value from a where row = 1 order by row_id";
    }
}
