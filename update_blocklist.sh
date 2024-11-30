<?php
// secuNX_403.php

// Set the response status code to 403 Forbidden
http_response_code(403);

// Gather necessary information
$remote_addr = $_SERVER['REMOTE_ADDR'] ?? 'N/A';
$request_uri = $_SERVER['REQUEST_URI'] ?? 'N/A';
$user_agent = $_SERVER['HTTP_USER_AGENT'] ?? 'N/A';
$time_local = date('Y-m-d H:i:s'); // Server's current time
$server_id = 'server1'; // Put a unique serverID here
$domain = $_SERVER['HTTP_HOST'] ?? 'N/A';

// Generate a random Block ID
$block_id = 'BLOCK' . strtoupper(substr(md5(uniqid()), 0, 6));

// Block details
$block_reason = 'Your IP address is listed in our blacklist and blocked from completing this request.';

// HTML Content
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Access Denied - SecuNX Website Firewall</title>
    <style>
        body {
            background-color: #f8f9fa;
            font-family: Arial, sans-serif;
            color: #333;
            text-align: center;
            padding: 50px;
        }
        .container {
            background-color: #ffffff;
            border: 1px solid #dee2e6;
            border-radius: 8px;
            display: inline-block;
            padding: 30px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        h1 {
            color: #dc3545;
            margin-bottom: 20px;
        }
        p {
            font-size: 16px;
            line-height: 1.5;
        }
        .details {
            background-color: #f1f3f5;
            border: 1px solid #ced4da;
            border-radius: 4px;
            padding: 15px;
            margin-top: 20px;
            text-align: left;
        }
        .details strong {
            display: inline-block;
            width: 150px;
        }
        a {
            color: #007bff;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
        footer {
            margin-top: 30px;
            font-size: 12px;
            color: #6c757d;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Access Denied</h1>
        <h2>SecuNX Website Firewall</h2>
        <p>If you are the site owner (or you manage this site), please whitelist your IP or if you think this block is an error, please <a href="http://support.vibrixmedia.com">open a support ticket</a> and make sure to include the block details (displayed below), so we can assist you in troubleshooting the issue.</p>
        <div class="details">
            <p><strong>Your IP:</strong> <?php echo htmlspecialchars($remote_addr); ?></p>
            <p><strong>URL:</strong> <?php echo htmlspecialchars("https://$domain$request_uri"); ?></p>
            <p><strong>Your Browser:</strong> <?php echo htmlspecialchars($user_agent); ?></p>
            <p><strong>Block ID:</strong> <?php echo htmlspecialchars($block_id); ?></p>
            <p><strong>Block Reason:</strong> <?php echo htmlspecialchars($block_reason); ?></p>
            <p><strong>Time:</strong> <?php echo htmlspecialchars($time_local); ?></p>
            <p><strong>Server ID:</strong> <?php echo htmlspecialchars($server_id); ?></p>
        </div>
    </div>
    <footer>
        &copy; 2024 SecuNX Web Application Firewall
    </footer>
</body>
</html>
