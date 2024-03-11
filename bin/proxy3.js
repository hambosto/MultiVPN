// Socket Bridge for SSH
// https://github.com/hambosto/MultiVPN

const net = require("net");
const DESTINATION_HOST = "127.0.0.1";
const DESTINATION_PORT = 189;
const LISTEN_PORT = 8888;

const server = net.createServer();

// Event listener for incoming client connections
server.on('connection', (socket) => {
    let packetCount = 0;

    // Respond to the client with the HTTP 101 status
    socket.write("HTTP/1.1 101 Switching Protocols\r\nContent-Length: 1048576000000\r\n\r\n");

    console.log(`[INFO] - Connection received from ${socket.remoteAddress}:${socket.remotePort}`);

    // Create a connection to the destination server
    const connection = net.createConnection({ host: DESTINATION_HOST, port: DESTINATION_PORT });

    // Set larger buffer sizes for higher bandwidth
    socket.setNoDelay(true);
    connection.setNoDelay(true);

    // Event listener for data received from the client
    socket.on('data', (data) => {
        if (packetCount >= 0) {
            // Forward data from the client to the destination server
            connection.write(data);
        }
        packetCount++;
    });

    // Event listener for data received from the destination server
    connection.on('data', (data) => {
        // Forward data from the destination server to the client
        socket.write(data);
    });

    // Handle the 'data' event only once for the initial interaction
    socket.once('data', () => {
        // Perform any initial setup if needed
    });

    // Event listener for errors on the client socket
    socket.on('error', (error) => {
        console.log(`[SOCKET] - Error reading from ${socket.remoteAddress}:${socket.remotePort}: ${error}`);
        connection.destroy();
    });

    // Event listener for errors on the destination server connection
    connection.on('error', (error) => {
        console.log(`[REMOTE] - Error reading from ${DESTINATION_HOST}:${DESTINATION_PORT}: ${error}`);
        socket.destroy();
    });

    // Event listener for the client socket close event
    socket.on('close', () => {
        console.log(`[INFO] - Connection terminated for ${socket.remoteAddress}:${socket.remotePort}`);
        connection.destroy();
    });
});

// Start the server and listen for incoming connections
server.listen(LISTEN_PORT, () => {
    console.log(`[INFO] - Server started on port: ${LISTEN_PORT}`);
    console.log(`[INFO] - Redirecting requests to: ${DESTINATION_HOST} at port ${DESTINATION_PORT}`);
});
