package com.example.MonaServer.JDBC;

import com.example.MonaServer.Entities.UserPassword;

import java.sql.*;
import java.util.Properties;


public class JDBC {

    private final SQL SQL_STRINGS = new SQL();
    private Connection conn;


    public JDBC()  {

        try {
            Class.forName("org.postgresql.Driver");
            Properties props = new Properties();
            props.put("user", System.getenv("DB_USER"));
            props.put("password", System.getenv("DB_PASSWORD"));

            conn = DriverManager.getConnection(System.getenv("DATASOURCE_URL") , props);
        } catch (Exception e) {
            System.out.println(e);
        }
    }




    public void dropTable(String sensor) {
        try {
           this.update(SQL_STRINGS.deleteEntryTable(), new Object[] {"s" + sensor});
            this.update(SQL_STRINGS.deleteEntryTable(), new Object[] {"backup_" + sensor});
        } catch(SQLException e) {
            System.out.println(e);
        }
    }
    private void prepareStatement(PreparedStatement stmt, Object[] objs) throws SQLException {
        int count = 0;
        for (Object obj : objs) {
            if (count > 0) {
                if (obj instanceof String) {
                    stmt.setString(count, (String) obj);
                } else if (obj instanceof Integer) {
                    stmt.setInt(count, (Integer) obj);
                } else if (obj instanceof Double) {
                    stmt.setDouble(count, (Double) obj);
                }else if (obj instanceof Long) {
                    stmt.setLong(count, (Long) obj);
                } else if (obj instanceof Timestamp) {
                    stmt.setTimestamp(count, (Timestamp) obj);
                }
            }
            count++;
        }
    }

    private void update(String sqlQuery, Object[] objs) throws SQLException {
        PreparedStatement stmt = conn.prepareStatement(this.setTableName(sqlQuery, (String) objs[0]));
        this.prepareStatement(stmt, objs);
        stmt.executeUpdate();
        stmt.close();
    }

    private void close() throws SQLException {
        conn.close();
    }

    private String setTableName(String sql, String tableName) {
        return sql.replace("$", tableName);
    }
}
