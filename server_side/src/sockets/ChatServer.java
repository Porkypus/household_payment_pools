package sockets;

import java.io.*;
import java.net.ConnectException;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.UnknownHostException;
import java.nio.charset.StandardCharsets;

public class ChatServer {
  public static void main(String args[]) throws IOException {
    if (args.length != 1) {
      System.out.println("Usage: java ChatServer <port>");
      return;
    }
    boolean isNumeric = args[0].chars().allMatch(Character::isDigit);
    if (!isNumeric) {
      System.out.println("Usage: java ChatServer <port>");
    }
    int port = Integer.parseInt(args[0]);

    final ServerSocket server = new ServerSocket(8080);
    server.setSoTimeout(0);
    System.out.println("waiting for connection...");

    while (true) {
      try {
        Socket client = server.accept();
        DataInputStream input = new DataInputStream(client.getInputStream());
        DataOutputStream output = new DataOutputStream(client.getOutputStream());
        BufferedReader reader = new BufferedReader(new InputStreamReader(input));
        System.out.println("connected to " + client.getLocalSocketAddress() + ".");
        
        while(true){
          byte help = input.readByte();
          while(help != 10){
            System.out.print(new String(new byte[]{help},StandardCharsets.UTF_8));
            help = input.readByte();
          }
          System.out.println();
        }
      } catch (IOException e) {
        System.out.println("disconnected.\n\nwaiting for connection...");
      }
    }
  }
}
