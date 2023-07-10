package server;

import DatabaseComm.MySqlCon;

import java.io.IOException;
import java.net.ServerSocket;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public class Server {
	static int port = 25565;
	private static final MySqlCon database = new MySqlCon();
	static Map<Integer, Set<ClientHandler>> online = new HashMap<>();

	public static void main(String[] args) {
		ServerSocket socket;
		try {
			socket = new ServerSocket(port);
		} catch (IOException e) {
			System.err.print("Port unavailable");
			return;
		}
		while (true) {
			try {
				Connection connection = new Connection(socket);
				Thread handleClient = new Thread(() -> {
					try {
						new ClientHandler(connection, database);
					} catch (IOException e) {
						e.printStackTrace();
					}
				});
				handleClient.start();
			} catch (IOException e) {
				e.printStackTrace();
			}
		}
	}
	public static void signIn(int uid, ClientHandler clientHandler) {
		if (!online.containsKey(uid)) {
			online.put(uid, new HashSet<>());
		}
		online.get(uid).add(clientHandler);
	}
}
