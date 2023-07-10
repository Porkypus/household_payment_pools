package DatabaseComm;

import java.sql.*;

import java.lang.*;
import java.util.*;
import java.util.Date;
import server.Notification;
import server.Transaction;


public class MySqlCon{

    Connection con;
    //MySQL server name
    String DBname = "household";
    //MySQL server username
    String username = "root";
    //MySQL server password
    String password = "Johnman1902!";

    public MySqlCon() {
        try {
            Class.forName("com.mysql.jdbc.Driver");
            con = DriverManager.getConnection(
                    "jdbc:mysql://localhost:3306/" + DBname, username, password);
            con.setAutoCommit(false);
        }catch(Exception e){ System.out.println(e);}
    }

    public Integer createHousehold(String name, int uid) {
        try{
            String update = "INSERT INTO households (NAME, UID) VALUES (?,?)";
            PreparedStatement stmt = con.prepareStatement(update);
            stmt = con.prepareStatement(update, Statement.RETURN_GENERATED_KEYS);
            stmt.setString(1,name);
            stmt.setInt(2,uid);
            stmt.executeUpdate();

            ResultSet rs = stmt.getGeneratedKeys();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            rs.next();
            return rs.getInt(1);
        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    /*public Integer createUser(String name, String email, String username, String password) {
        try{
            Statement stmt=con.createStatement();
            String update = "INSERT INTO users (name, email_address, username, password) VALUES('" + name + "', '"+ email +"', '" + username + "', '" + password + "');";
            stmt = con.prepareStatement(update, Statement.RETURN_GENERATED_KEYS);
            stmt.executeUpdate(update, Statement.RETURN_GENERATED_KEYS);
            ResultSet rs = stmt.getGeneratedKeys();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            rs.next();
            return rs.getInt(1);
        }catch(Exception e){ System.out.println(e);}
        return null;
    }*/

    public Integer createUser(String username, String password) {
        try{
            String update = "INSERT INTO users (username, password) VALUES(?,?);";
            PreparedStatement stmt=con.prepareStatement(update,Statement.RETURN_GENERATED_KEYS);
            stmt.setString(1,username);
            stmt.setString(2,password);
            stmt.executeUpdate();
            ResultSet rs = stmt.getGeneratedKeys();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            rs.next();
            return rs.getInt(1);
        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public boolean addToHousehold(int uid, int hid) {
        try{
            String update = "INSERT INTO usermembers (userid, householdid, budget, spent, charged) VALUES(?,?,0, 0, 0);";
            PreparedStatement stmt=con.prepareStatement(update);
            stmt.setInt(1,uid);
            stmt.setInt(2,hid);
            stmt.executeUpdate();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
                return true;
            }
            return false;
        }catch(Exception e){ System.out.println(e); return false;}
    }

    public boolean addToHousehold(int uid, int hid, int budget) {
        try{
            String update = "INSERT INTO usermembers (userid, householdid, budget, spent, charged) VALUES(?,?,?, 0, 0);";
            PreparedStatement stmt = con.prepareStatement(update);
            stmt.setInt(1,uid);
            stmt.setInt(2,hid);
            stmt.setInt(3,budget);
            stmt.executeUpdate();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
                return true;
            }
            return false;
        }catch(Exception e){ System.out.println(e);return false;}
    }

    public boolean setBudget(int uid, int hid, int budget) {
        try{
            String update = "UPDATE usermembers " +
                    "SET" +
                    "    budget = ?" +
                    " WHERE" +
                    " userid = ? AND householdid = ?;";
            PreparedStatement stmt=con.prepareStatement(update);
            stmt.setInt(1,budget);
            stmt.setInt(2,uid);
            stmt.setInt(3,hid);
            stmt.executeUpdate();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
                return true;
            }
            return false;
        }catch(Exception e){ System.out.println(e);return false;}
    }

    public boolean setUserName(int uid, String name) {
        try{
            String update = "UPDATE users " +
                    "SET" +
                    "    name = ?" +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt = con.prepareStatement(update);
            stmt.setString(1,name);
            stmt.setInt(2,uid);
            stmt.executeUpdate();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
                return true;
            }
            return false;
        }catch(Exception e){ System.out.println(e);return false;}
    }

    public boolean setUserUsername(int uid, String username) {
        try{
            String update = "UPDATE users " +
                    "SET" +
                    "    username = ?" +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt=con.prepareStatement(update);
            stmt.setString(1,username);
            stmt.setInt(2,uid);
            stmt.executeUpdate();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
                return true;
            }
            return false;
        }catch(Exception e){ System.out.println(e);return false;}
    }

    public boolean setUserPassword(int uid, String password) {
        try{
            String update = "UPDATE users " +
                    "SET" +
                    "    password = ?" +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt=con.prepareStatement(update);
            stmt.setString(1,password);
            stmt.setInt(2,uid);
            stmt.executeUpdate();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
                return true;
            }
            return false;
        }catch(Exception e){ System.out.println(e);return false;}
    }

    public boolean setUserEmail(int uid, String email) {
        try{

            String update = "UPDATE users " +
                    "SET" +
                    "    email_address = ?" +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt=con.prepareStatement(update);
            stmt.setString(1,email);
            stmt.setInt(2,uid);
            stmt.executeUpdate();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                return true;
            }
            return false;
        }catch(Exception e){ System.out.println(e);return false;}
    }

    public boolean setHouseholdName(int hid, String name) {
        try{
            String update = "UPDATE households " +
                    "SET" +
                    "    name = ?" +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt=con.prepareStatement(update);
            stmt.setString(1,name);
            stmt.setInt(2,hid);
            stmt.executeUpdate();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
                return true;
            }
            return false;
        }catch(Exception e){ System.out.println(e);return false;}
    }

    public boolean setHouseholdLeader(int hid, int uid) {
        try{
            String update = "UPDATE households " +
                    "SET" +
                    "    uid = ?" +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt=con.prepareStatement(update);
            stmt.setInt(1,uid);
            stmt.setInt(2,hid);
            stmt.executeUpdate();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
                return true;
            }
            return false;
        }catch(Exception e){ System.out.println(e);return false;}
    }

    public boolean incrementActualSpend(int uid, int hid, int num) {
        try{
            String query = "SELECT spent FROM usermembers " +
                    " WHERE" +
                    "    userid = ? AND householdid = ?;";
            PreparedStatement stmt=con.prepareStatement(query);
            stmt.setInt(1,uid);
            stmt.setInt(2,hid);
            ResultSet rs = stmt.executeQuery();
            int temp = num;
            if(rs.next()) {
                temp += rs.getInt("spent");
            }else {
                System.out.println("NO RESULT");
            }
            String update = "UPDATE usermembers " +
                    "SET" +
                    "    spent = ?" +
                    " WHERE" +
                    "    userid = ? AND householdid = ?;";
            stmt=con.prepareStatement(update);
            stmt.setInt(1,temp);
            stmt.setInt(2,uid);
            stmt.setInt(3,hid);
            stmt.executeUpdate();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
                return true;
            }
            return false;
        }catch(Exception e){ System.out.println(e);return false;}
    }

    public boolean incrementCharged(int uid, int hid, int num) {
        try{

            String query = "SELECT charged FROM usermembers " +
                    " WHERE" +
                    "    userid = ? AND householdid = ?;";
            PreparedStatement stmt=con.prepareStatement(query);
            stmt.setInt(1,uid);
            stmt.setInt(2,hid);
            ResultSet rs = stmt.executeQuery();
            int temp = num;
            if(rs.next()) {
                temp += rs.getInt("charged");
            }else {
                System.out.println("NO RESULT");
            }
            String update = "UPDATE usermembers " +
                    "SET" +
                    "    charged = ?"+
                    " WHERE" +
                    "    userid = ? AND householdid = ?;";
            stmt = con.prepareStatement(update);
            stmt.setInt(1,temp);
            stmt.setInt(2,uid);
            stmt.setInt(3,hid);
            stmt.executeUpdate();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
                return true;
            }
            return false;
        }catch(Exception e){ System.out.println(e);return false;}
    }

    public Integer createTransaction(String title,int uid, int hid, int amount) {
        try{
            Date date = new Date();
            Timestamp timestamp = new Timestamp(date.getTime());
            String update = "INSERT INTO transactions (title, hid, uid, amount, timestamp) VALUES(?,?,?,?,?);";
            PreparedStatement stmt=con.prepareStatement(update,Statement.RETURN_GENERATED_KEYS);
            stmt.setString(1,title);
            stmt.setInt(2,hid);
            stmt.setInt(3,uid);
            stmt.setInt(4,amount);
            stmt.setTimestamp(5,timestamp);
            stmt.executeUpdate();
            ResultSet rs = stmt.getGeneratedKeys();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            rs.next();
            return rs.getInt(1);
        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public Integer createNotification(int uid, String title, String body, String options,String type) {
        try{
            Date date = new Date();
            Timestamp timestamp = new Timestamp(date.getTime());
            String update = "INSERT INTO notifications (uid, title, body, options, timestamp, type) VALUES(?,?,?,?,?,?);";
            PreparedStatement stmt = con.prepareStatement(update, Statement.RETURN_GENERATED_KEYS);
            stmt.setInt(1,uid);
            stmt.setString(2,title);
            stmt.setString(3,body);
            stmt.setString(4,options);
            stmt.setTimestamp(5,timestamp);
            stmt.setString(6,type);
            stmt.executeUpdate();
            ResultSet rs = stmt.getGeneratedKeys();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            rs.next();
            return rs.getInt(1);
        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public Integer createNotification(Notification n) {
        try{
            Date date = new Date();
            Timestamp timestamp = new Timestamp(date.getTime());
            String update = "INSERT INTO notifications (id, uid, title, body, options, timestamp,type) VALUES(?,?,?,?,?,?,?);";
            PreparedStatement stmt = con.prepareStatement(update, Statement.RETURN_GENERATED_KEYS);
            stmt.setInt(1,n.getNid());
            stmt.setInt(2,n.getUid());
            stmt.setString(3,n.getTitle());
            stmt.setString(4,n.getBody());
            stmt.setString(5,n.getOptions());
            stmt.setTimestamp(6,new Timestamp(n.getTimestamp().getTime()));
            stmt.setString(7,n.getType());
            stmt.executeUpdate();
            ResultSet rs = stmt.getGeneratedKeys();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            rs.next();
            return n.getNid();
        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public boolean createPayment(int tid, int uid, int amount) {
        try{

            String update = "INSERT INTO payments (tid, uid, amount) VALUES(?,?,?);";
            PreparedStatement stmt=con.prepareStatement(update);
            stmt.setInt(1,tid);
            stmt.setInt(2,uid);
            stmt.setInt(3,amount);
            stmt.executeUpdate();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
                return true;
            }
            return false;
        }catch(Exception e){ System.out.println(e);return false;}
    }

    public boolean createInvite(int hid, int uid) {
        try{
            String update = "INSERT INTO invites (hid, uid) VALUES(?,?);";
            PreparedStatement stmt=con.prepareStatement(update);
            stmt.setInt(1,hid);
            stmt.setInt(2,uid);
            stmt.executeUpdate();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
                return true;
            }
            return false;
        }catch(Exception e){ System.out.println(e);return false;}
    }

    public String getUserName(int uid) {
        try {
            String query = "SELECT name FROM users " +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,uid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return rs.getString("name");
            }

        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public String getUserEmail(int uid) {
        try {
            String query = "SELECT email_address FROM users " +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,uid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return rs.getString("email_address");
            }

        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public String getUserUName(int uid) {
        try {
            String query = "SELECT username FROM users " +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,uid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return rs.getString("username");
            }

        }catch(Exception e){ System.out.println(e);}
        return null;
    }
    public String getUserPassword(int uid) {
        try {
            String query = "SELECT password FROM users " +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,uid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return rs.getString("password");
            }

        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public boolean inUserHousehold(int uid, int hid) {
        try {

            String query = "SELECT * FROM usermembers" +
                    " WHERE" +
                    "    householdid = ? AND userid = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,hid);
            stmt.setInt(2,uid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return true;
            }

        }catch(Exception e){ System.out.println(e);}
        return false;
    }

    public Integer getUserBudget(int uid, int hid) {
        try {

            String query = "SELECT budget FROM usermembers " +
                    " WHERE" +
                    "    userid = ? AND householdid = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,uid);
            stmt.setInt(2,hid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return rs.getInt("budget");
            }

        }catch(Exception e){ System.out.println("getUserBudget" + e);}
        return null;
    }
    public Integer getUserCharged(int uid, int hid) {
        try {
            String query = "SELECT charged FROM usermembers " +
                    " WHERE" +
                    "    userid = ? AND householdid = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,uid);
            stmt.setInt(2,hid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return rs.getInt("charged");
            }

        }catch(Exception e){ System.out.println("getUserCharged" + e);}
        return null;
    }
    public Integer getUserSpent(int uid, int hid) {
        try {
            String query = "SELECT spent FROM usermembers " +
                    " WHERE" +
                    "    userid = ? AND householdid = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,uid);
            stmt.setInt(2,hid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return rs.getInt("spent");
            }

        }catch(Exception e){ System.out.println("getUserSpent" + e);}
        return null;
    }

    public String getHouseholdName(int hid) {
        try {

            String query = "SELECT name FROM households " +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,hid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return rs.getString("name");
            }

        }catch(Exception e){ System.out.println(e);}
        return null;
    }
    public Integer getHouseholdLeader(int hid) {
        try {
            String query = "SELECT uid FROM households " +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,hid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return rs.getInt("uid");
            }

        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public Integer getTransactionHousehold(int tid) {
        try {

            String query = "SELECT hid FROM transactions " +
                    " WHERE" +
                    "    id = " + tid + ";";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,tid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return rs.getInt("hid");
            }

        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public Integer getTransactionUser(int tid) {
        try {
            String query = "SELECT uid FROM transactions " +
                    " WHERE" +
                    "    id = " + tid + ";";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,tid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return rs.getInt("uid");
            }

        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public Integer getTransactionAmount(int tid) {
        try {
            String query = "SELECT amount FROM transactions " +
                    " WHERE" +
                    "    id = " + tid + ";";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,tid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return rs.getInt("amount");
            }

        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public Date getTransactionTimestamp(int tid) {
        try {
            String query = "SELECT timestamp FROM transactions " +
                    " WHERE" +
                    "    id = " + tid + ";";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,tid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return new Date(rs.getTimestamp("timestamp").getTime());
            }

        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public String getTransactionTitle(int tid) {
        try {
            String query = "SELECT title FROM transactions " +
                    " WHERE" +
                    "    id = " + tid + ";";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,tid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return rs.getString("title");
            }

        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public Integer getNotificationUser(int nid) {
        try {
            String query = "SELECT uid FROM notifications " +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,nid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return rs.getInt("uid");
            }

        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public String getNotificationTitle(int nid) {
        try {
            String query = "SELECT title FROM notifications " +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,nid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return rs.getString("title");
            }

        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public String getNotificationBody(int nid) {
        try {
            String query = "SELECT body FROM notifications " +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,nid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return rs.getString("body");
            }

        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public String getNotificationOptions(int nid) {
        try {
            String query = "SELECT options FROM notifications " +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,nid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return rs.getString("options");
            }

        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public Date getNotificationTimeStamp(int nid) {
        try {
            String query = "SELECT timestamp FROM notifications " +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,nid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return new Date(rs.getTimestamp("timestamp").getTime());
            }

        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public String getNotificationType(int nid) {
        try {
            String query = "SELECT type FROM notifications " +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,nid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return rs.getString("type");
            }

        }catch(Exception e){ System.out.println(e);}
        return null;
    }


    public List<Integer> getAllUsers(int hid) {
        try {

            String query = "SELECT userid FROM usermembers " +
                    " WHERE" +
                    "    householdid = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,hid);
            ResultSet rs = stmt.executeQuery();
            ArrayList<Integer> users = new ArrayList<Integer>();
            while(rs.next()) {
                users.add(rs.getInt("userid"));
            }
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            return users;
        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public List<Integer> getAllPaymentUsers(int tid) {
        try {

            String query = "SELECT uid FROM payments " +
                    " WHERE" +
                    "    tid = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,tid);
            ResultSet rs = stmt.executeQuery();
            ArrayList<Integer> users = new ArrayList<Integer>();
            while(rs.next()) {
                users.add(rs.getInt("uid"));
            }
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            return users;
        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public List<Integer> getAllHouseholds(int uid) {
        try {

            String query = "SELECT householdid FROM usermembers " +
                    " WHERE" +
                    "    userid = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,uid);
            ResultSet rs = stmt.executeQuery();
            ArrayList<Integer> users = new ArrayList<Integer>();
            while(rs.next()) {
                users.add(rs.getInt("householdid"));
            }
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            return users;
        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public Integer getPayment(int tid, int uid) {
        try {
            String query = "SELECT amount FROM payments " +
                    " WHERE" +
                    "    tid = ? AND uid = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,tid);
            stmt.setInt(2,uid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return rs.getInt("amount");
            }

        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public List<Integer> getPaymentUsers(int tid) {
        try {
            String query = "SELECT uid FROM payments " +
                    " WHERE" +
                    "    tid = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,tid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            ArrayList<Integer> res = new ArrayList<Integer>();
            while (rs.next()) {
                res.add(rs.getInt("uid"));
            }
            return res;

        }catch(Exception e){ System.out.println("getPaymentUsers issue " + e);}
        return null;
    }

    public boolean getInvite(int hid, int uid) {
        try {

            String query = "SELECT * FROM invites " +
                    " WHERE" +
                    "    hid = ? AND uid = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,hid);
            stmt.setInt(2,uid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            if (rs.next()) {
                return true;
            }

        }catch(Exception e){ System.out.println(e);}
        return false;
    }
    public boolean deleteUsersEntry(int uid) {
        try {

            String query = "DELETE FROM users " +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,uid);
            stmt.executeUpdate();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
                return true;
            }
            return false;
        }catch(Exception e){ System.out.println(e);return false;}
    }
    public boolean deleteHouseholdsEntry(int hid) {
        try {

            String query = "DELETE FROM households " +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,hid);
            stmt.executeUpdate();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
                return true;
            }
            return false;
        }catch(Exception e){ System.out.println(e);return false;}
    }

    public boolean deleteTransactionsEntry(int tid) {
        try {

            String query = "DELETE FROM transactions " +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,tid);
            stmt.executeUpdate();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
                return true;
            }
            return false;
        }catch(Exception e){ System.out.println(e);return false;}
    }

    public boolean deleteNotificationsEntry(int nid) {
        try {

            String query = "DELETE FROM notifications " +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,nid);
            stmt.executeUpdate();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
                return true;
            }
            return false;
        }catch(Exception e){ System.out.println(e);return false;}
    }

    public boolean deleteInvitesEntry(int hid, int uid) {
        try {

            String query = "DELETE FROM invites " +
                    " WHERE" +
                    "    hid = ? AND uid = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,hid);
            stmt.setInt(2,uid);
            stmt.executeUpdate();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
                return true;
            }
            return false;
        }catch(Exception e){ System.out.println(e);return false;}
    }
    public boolean deletePaymentsEntry(int tid, int uid) {
        try {

            String query = "DELETE FROM payments " +
                    " WHERE" +
                    "    tid = ? AND uid = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,tid);
            stmt.setInt(2,uid);
            stmt.executeUpdate();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
                return true;
            }
            return false;
        }catch(Exception e){ System.out.println(e);return false;}
    }

    public boolean deleteUserMembersEntry(int hid, int uid) {
        try {

            String query = "DELETE FROM usermembers " +
                    " WHERE" +
                    "    householdid = ? AND userid = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,hid);
            stmt.setInt(2,uid);
            stmt.executeUpdate();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
                return true;
            }
            return false;
        }catch(Exception e){ System.out.println(e);return false;}
    }

    public Integer getUid(String username) {
        try {

            String query = "SELECT id FROM users " +
                    " WHERE" +
                    "    username = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setString(1,username);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
           if(rs.next()) {
                return rs.getInt("id");
            }

        }catch(Exception e){ System.out.println(e);}
        return null;
    }



    public List<Notification> getNotifications(int uid) {
        try {
            String query = "SELECT * FROM notifications " +
                    " WHERE" +
                    "    uid = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,uid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            List<Notification> nf =new ArrayList<Notification>();
            while(rs.next()) {
                nf.add( new Notification(rs.getInt("id"), rs.getInt("uid"), rs.getString("type"),rs.getString("title"), rs.getString("body"), rs.getString("options"), new Date(rs.getTimestamp("timestamp").getTime())));
            }
            return nf;

        }catch(Exception e){ System.out.println(e);}
        return null;
    }

    public Notification getNotification(int nid) {
        try {

            String query = "SELECT * FROM notifications " +
                    " WHERE" +
                    "    id = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,nid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            //List<Notification> nf =new ArrayList<Notification>();
            if(rs.next()) {
               return new Notification(rs.getInt("id"), rs.getInt("uid"), rs.getString("type"),rs.getString("title"), rs.getString("body"), rs.getString("options"), new Date(rs.getTimestamp("timestamp").getTime()));
            }
            return null;

        }catch(Exception e){ System.out.println(e);}
        return null;
    }



    public List<Transaction> getTransactions(int uid) {
        try {

            String query = "SELECT id FROM transactions " +
                    " WHERE" +
                    "    uid = ?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1,uid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }
            List<Integer> nf =new ArrayList<Integer>();
            while(rs.next()) {
                nf.add(rs.getInt("id"));
            }
            List<Transaction> tf = new ArrayList<Transaction>();

            for(int tid: nf) {
                tf.add(getTransaction(tid));
            }
            return tf;

        }catch(Exception e){ System.out.println("getTransaction Issue " + e);}
        return null;
    }

    public Transaction getTransaction(int tid) {
        try {

            String query = "SELECT * FROM transactions " +
                    " WHERE" +
                    "    id =?;";
            PreparedStatement stmt = con.prepareStatement(query);
            stmt.setInt(1, tid);
            ResultSet rs = stmt.executeQuery();
            DatabaseMetaData dbMetaData = con.getMetaData();
            if (dbMetaData.supportsTransactionIsolationLevel(8)) {
                con.setTransactionIsolation(8);
                con.commit();
            }

            List<Integer> a = getPaymentUsers(tid);
            Map<Integer, Integer> mp = new HashMap<Integer, Integer>();
            if (a != null) {
                for (Integer user : a) {
                    mp.put(user, getPayment(tid, user));
                }
            }

            rs.next();
            return new Transaction(rs.getString("title"),rs.getInt("hid"),rs.getInt("amount"),rs.getInt("uid"),new Date(rs.getTimestamp("timestamp").getTime()),mp);

        }catch(Exception e){ System.out.println("getTransaction (singular) " + e);}
        return null;
    }



    public void close() {
        try {
            con.close();
        }catch(Exception e){ System.out.println(e);}
    }

    public void test(){
        try{
            Class.forName("com.mysql.jdbc.Driver");
            Connection con=DriverManager.getConnection(
                    "jdbc:mysql://localhost:3306/applications","root","Johnman1902!");
//here sonoo is database name, root is username and password
            Statement stmt=con.createStatement();
            ResultSet rs=stmt.executeQuery("select * from resumes");
            while(rs.next())
                System.out.println(rs.getInt(1)+"  "+rs.getString(2)+"  "+rs.getString(3));
            String sql = "UPDATE resumes " +
                    "SET name = 'weinerboy' WHERE id in (1,3)";
            stmt.executeUpdate(sql);
            rs = stmt.executeQuery("select * from resumes");
            while(rs.next())
                System.out.println(rs.getInt(1)+"  "+rs.getString(2)+"  "+rs.getString(3));
            con.close();
        }catch(Exception e){ System.out.println(e);}
    }

}