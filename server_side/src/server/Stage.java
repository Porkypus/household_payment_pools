package server;

public enum Stage {
	CONNECTED, HANDSHAKE, LOGGEDIN, LOGGEDOUT
    /*
    Represents the connection stage:
        CONNECTED:	just connected; waiting for initial "HOUSEPAYCLIENT"
        HANDSHAKE:	initial "HOUSEPAYCLIENT" sent, waiting for confirmation of the HANDSHAKE
        LOGGEDOUT:	setup complete; receiving requests when logged out
        LOGGEDIN:   user is logged in and can ask about his account in requests
     */
}
