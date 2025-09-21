<?php
// secuNX_403.php

// Set the response status code to 403 Forbidden
http_response_code(403);

// Gather necessary information
$remote_addr = $_SERVER['REMOTE_ADDR'] ?? 'N/A';
$request_uri = $_SERVER['REQUEST_URI'] ?? 'N/A';
$user_agent = $_SERVER['HTTP_USER_AGENT'] ?? 'N/A';
$time_local = date('Y-m-d H:i:s'); // Server's current time
$server_id = 'vibrix2024'; // Server ID
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
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Access Denied - SecuNX Website Firewall</title>
    <style>
        body {
            background-color: #f8f9fa;
            font-family: Arial, sans-serif;
            color: #333;
            text-align: center;
            padding: 20px;
        }
        .container {
            background-color: #ffffff;
            border: 1px solid #dee2e6;
            border-radius: 8px;
            display: inline-block;
            padding: 20px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            max-width: 800px;
            width: 100%;
        }
        h1 {
            color: #dc3545;
            margin-bottom: 15px;
            font-size: 24px;
        }
        h2 {
            font-size: 20px;
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
            padding: 10px;
            margin-top: 15px;
            text-align: left;
            font-size: 14px;
        }
        .details strong {
            display: inline-block;
            width: 120px;
            /* Ensure font size matches body text */
            font-size: 14px;
        }
        a {
            color: #007bff;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
        footer {
            margin-top: 20px;
            font-size: 12px;
            color: #6c757d;
        }

        /* Mobile Responsive Styles */
        @media (max-width: 600px) {
            .container {
                padding: 15px;
                width: 90%;
            }
            h1 {
                font-size: 20px;
            }
            h2 {
                font-size: 18px;
            }
            p, .details {
                font-size: 10px !important;
            }
            .details strong {
                width: 100px;
                /* Remove font-size adjustment to match body text */
                font-size: 10px !important;
