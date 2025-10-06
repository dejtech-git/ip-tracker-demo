# Real-time IP Tracker for ES Sharing Application

A real-time web application that displays connected users' IP addresses and browser information with automatic session management, deployed on AWS with auto-scaling infrastructure.

## ✅ Features

- **Real-time IP tracking** with WebSocket communication
- **QR code generation** for easy mobile access
- **EC2 Instance ID tracking** with IMDSv1/v2 support
- **Automatic session management** (no manual logout required)
- **3 connection limit per instance** with error page when exceeded
- **JavaScript heartbeat** mechanism (30s intervals)
- **Real-time duration counter** that accurately tracks connection time
- **Automatic cleanup** of inactive sessions (300s timeout)
- **Security features**: Input sanitization, rate limiting, XSS prevention
- **Browser/OS detection** from User-Agent strings
- **Bootstrap UI** with responsive design
- **AWS Infrastructure**: VPC, ALB, Auto Scaling, ElastiCache Redis, EC2 instances
- **Infrastructure as Code**: Terraform deployment with version control

## 🏗️ Project Structure

```
Demo1/
├── main.tf                 # Terraform infrastructure configuration
├── user_data_working.sh    # EC2 instance bootstrap script
├── templates/
│   ├── base.html           # Base template with Bootstrap
│   ├── index.html          # Main page with real-time updates
│   └── error.html          # Maximum users error page
├── app.py                  # Main Flask application (local development)
├── requirements.txt        # Python dependencies
├── test_app.py            # Test suite
└── run.sh                 # Startup script
```

## 🚀 Quick Start

### Local Development

1. **Run the application:**
   ```bash
   ./run.sh
   ```

2. **Access the application:**
   - Open browser to `http://localhost:8800`
   - Scan the QR code from mobile devices
   - See real-time updates as users connect/disconnect

3. **Run tests:**
   ```bash
   source venv/bin/activate
   python test_app.py
   ```

### AWS Deployment

1. **Deploy infrastructure:**
   ```bash
   terraform init
   terraform apply
   ```

2. **Access the application:**
   - Use the `website_url` output from Terraform
   - Example: `http://ip-tracker-alb-306488846.us-east-1.elb.amazonaws.com/app-x7k9m2n8/`

3. **Update instances after code changes:**
   ```bash
   # Apply Terraform updates
   terraform apply
   
   # Force refresh all instances immediately
   aws autoscaling start-instance-refresh --auto-scaling-group-name ip-tracker-asg --preferences '{"MinHealthyPercentage": 0, "InstanceWarmup": 60}' --region us-east-1
   ```

## 🔧 Technical Details

- **Backend**: Python Flask with Flask-SocketIO
- **Frontend**: Bootstrap 5 + JavaScript WebSocket client with real-time duration counter
- **Session Storage**: Redis for distributed session management across instances
- **Real-time Communication**: WebSocket with automatic reconnection
- **Load Balancing**: ALB with sticky sessions and least outstanding requests algorithm
- **EC2 Metadata**: IMDSv1/v2 support for instance ID retrieval
- **Security**: Rate limiting (10 req/min), input sanitization, XSS prevention

## 🧪 Test Results

All core functionality tests pass:
- ✅ Session management (CRUD operations)
- ✅ Browser/OS detection
- ✅ Security functions (XSS prevention, rate limiting)
- ✅ QR code generation

## 🔒 Security Features

- **Input Validation**: All user inputs are sanitized and validated
- **Rate Limiting**: 10 requests per minute per IP address
- **XSS Prevention**: HTML escaping and input sanitization
- **Session Security**: UUID-based session IDs with automatic expiration
