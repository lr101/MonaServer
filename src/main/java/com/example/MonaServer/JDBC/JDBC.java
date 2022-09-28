package com.example.MonaServer.JDBC;

import com.example.MonaServer.Entities.UserPassword;
import com.example.MonaServer.Entities.Versioning;
import org.springframework.beans.factory.annotation.Value;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;


public class JDBC {

    private final SQL SQL_STRINGS = new SQL();
    private Connection conn;

    @Value("${spring.datasource.username}")
    private String user;

    @Value("${spring.datasource.password}")
    private String password;

    @Value("${spring.datasource.url}")
    private String jdbcDBString;


    public JDBC()  {

        try {
            Class.forName("org.postgresql.Driver");
            Properties props = new Properties();
            props.put("user", user);
            props.put("password", password);

            conn = DriverManager.getConnection(jdbcDBString , props);
        } catch (Exception e) {
            System.out.println(e);
        }
    }


    public List<Versioning> getVersionsOverNum(Long number) {
        try {
            return selectVersions(new Object[]{"versions", number}, SQL_STRINGS.selectVersionsOverNum());
        } catch (Exception e) {
            System.out.println(e);
            return new ArrayList<>();
        }
    }

    private List<Versioning> selectVersions(Object[] params, String sql) throws SQLException {
        PreparedStatement stmt = conn.prepareStatement(this.setTableName(sql, (String) params[0]));
        this.prepareStatement(stmt, params);
        ResultSet rs = stmt.executeQuery();
        ArrayList<Versioning> entries = new ArrayList<>();
        while (rs.next()) {
            Versioning entry = new Versioning(rs.getLong("id"), rs.getLong("pin_id"), rs.getInt("type"));
            entries.add(entry);
        }
        rs.close();
        stmt.close();
        return entries;
    }

    public void dropTable(String name) {
        try {
           this.update(SQL_STRINGS.deleteEntryTable(), new Object[] {name});
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
