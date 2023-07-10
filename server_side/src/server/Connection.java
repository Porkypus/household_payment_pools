package server;

import java.io.IOException;
import java.net.ServerSocket;
import java.net.Socket;

public class Connection {
	int UserID;
	Socket socket;
	public Connection(ServerSocket serverSocket) throws IOException {
		socket = serverSocket.accept();
		this.UserID = Authenticate(socket);
	}
	public int Authenticate(Socket socket) {
		return 0;
	}
}
