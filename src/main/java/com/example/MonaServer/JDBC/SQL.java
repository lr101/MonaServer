package com.example.MonaServer.JDBC;

public class SQL {

    public String updateById() {return "UPDATE $ SET id=? WHERE id=?";}

    public String selectVersionsOverNum() {
        return "SELECT * FROM $ WHERE id > ? ORDER BY id";
    }

    public String deleteEntryTable() {
        return "DROP TABLE $";
    }
}
