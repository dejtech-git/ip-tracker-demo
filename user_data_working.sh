#!/bin/bash
yum update -y
yum install -y python3 python3-pip git awscli amazon-cloudwatch-agent

# Install Python dependencies
pip3 install Flask Flask-SocketIO qrcode Pillow redis requests

# Get Redis endpoint from SSM Parameter Store
REDIS_HOST=$(aws ssm get-parameter --name "/ip-tracker/redis-endpoint" --query "Parameter.Value" --output text --region us-east-1 2>/dev/null || echo "localhost")
export REDIS_HOST=$REDIS_HOST

# Set SECRET_PATH environment variable
export SECRET_PATH="app-x7k9m2n8"

# Create application directory
mkdir -p /opt/ip-tracker
cd /opt/ip-tracker

# Create the Flask application
cat > app.py << 'EOF'
from flask import Flask, render_template, request
from flask_socketio import SocketIO, emit
import redis
import json
import uuid
import time
import os
import qrcode
import io
import requests

app = Flask(__name__)
app.config['SECRET_KEY'] = 'dev-secret-key'

# Get secret path from environment
SECRET_PATH = os.environ.get('SECRET_PATH', 'app-x7k9m2n8')

# Get EC2 instance ID with IMDSv1/v2 support
def get_instance_id():
    try:
        # Try IMDSv2
        token_response = requests.put('http://169.254.169.254/latest/api/token', headers={'X-aws-ec2-metadata-token-ttl-seconds': '21600'}, timeout=2)
        if token_response.status_code == 200:
            token = token_response.text
            response = requests.get('http://169.254.169.254/latest/meta-data/instance-id', headers={'X-aws-ec2-metadata-token': token}, timeout=2)
            if response.status_code == 200:
                return response.text.strip()
    except:
        pass
    try:
        # Fallback to IMDSv1
        response = requests.get('http://169.254.169.254/latest/meta-data/instance-id', timeout=2)
        if response.status_code == 200:
            return response.text.strip()
    except:
        pass
    return 'local-instance'

INSTANCE_ID = get_instance_id()

# Configure Socket.IO with the secret path
socketio = SocketIO(app, cors_allowed_origins="*", path=f'/{SECRET_PATH}/socket.io')

# Redis connection
redis_host = os.getenv('REDIS_HOST', 'localhost')
try:
    r = redis.Redis(host=redis_host, port=6379, decode_responses=True)
    r.ping()
    print(f"Connected to Redis at {redis_host}")
except:
    print("Redis connection failed, using in-memory storage")
    r = None

sessions = {}
websocket_sessions = {}

def get_client_ip():
    if request.headers.get('X-Forwarded-For'):
        return request.headers.get('X-Forwarded-For').split(',')[0].strip()
    return request.remote_addr

def detect_browser_os(user_agent):
    browser = 'Unknown'
    os_name = 'Unknown'
    
    # Browser detection
    if 'Chrome' in user_agent and 'Edg' not in user_agent:
        browser = 'Chrome'
    elif 'Firefox' in user_agent:
        browser = 'Firefox'
    elif 'Safari' in user_agent and 'Chrome' not in user_agent:
        browser = 'Safari'
    elif 'Edg' in user_agent:
        browser = 'Edge'
    
    # OS detection
    if 'Windows' in user_agent:
        os_name = 'Windows'
    elif 'Mac OS' in user_agent or 'macOS' in user_agent:
        os_name = 'macOS'
    elif 'Linux' in user_agent and 'Android' not in user_agent:
        os_name = 'Linux'
    elif 'Android' in user_agent:
        os_name = 'Android'
    elif 'iPhone' in user_agent or 'iPad' in user_agent:
        os_name = 'iOS'
    
    return {"browser": browser, "os": os_name}

def add_session(ip, user_agent, headers):
    session_id = str(uuid.uuid4())
    current_time = time.time()
    session_data = {
        'id': session_id, 'ip': ip, 'user_agent': user_agent,
        'headers': headers, 'start_time': current_time, 'timestamp': current_time, 'instance_id': INSTANCE_ID
    }
    
    if r:
        r.setex(f"session:{session_id}", 300, json.dumps(session_data))
    else:
        sessions[session_id] = session_data
    
    return session_id

def get_active_sessions():
    if r:
        active_sessions = []
        for key in r.scan_iter(match="session:*"):
            session_data = r.get(key)
            if session_data:
                data = json.loads(session_data)
                active_sessions.append(data)
        return active_sessions
    else:
        current_time = time.time()
        return [data for data in sessions.values() if current_time - data['timestamp'] < 300]

def get_instance_connection_count():
    return len(websocket_sessions)

@app.route(f'/{SECRET_PATH}/')
@app.route(f'/{SECRET_PATH}')
@app.route('/')
def index():
    ip = get_client_ip()
    if get_instance_connection_count() >= 3:
        return render_template('error.html'), 503
    
    user_agent = request.headers.get('User-Agent', 'Unknown')
    browser_info = detect_browser_os(user_agent)
    headers = {'user_agent': user_agent, **browser_info}
    session_id = add_session(ip, user_agent, headers)
    base_url = request.url_root.rstrip('/') + f'/{SECRET_PATH}/'
    
    return render_template('index.html', 
                         session_id=session_id, 
                         current_ip=ip, 
                         website_url=base_url,
                         secret_path=SECRET_PATH)

@app.route('/health')
def health():
    return {'status': 'healthy', 'connections': get_instance_connection_count()}

@app.route(f'/{SECRET_PATH}/qr-code')
def qr_code():
    base_url = request.url_root.rstrip('/') + f'/{SECRET_PATH}/'
    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data(base_url)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    buffer = io.BytesIO()
    img.save(buffer, format='PNG')
    buffer.seek(0)
    return buffer.getvalue(), 200, {'Content-Type': 'image/png'}

@socketio.on('connect')
def handle_connect():
    print(f'Client connected: {request.sid}')

@socketio.on('disconnect')
def handle_disconnect():
    if request.sid in websocket_sessions:
        session_id = websocket_sessions[request.sid]
        if r:
            r.delete(f"session:{session_id}")
        else:
            sessions.pop(session_id, None)
        del websocket_sessions[request.sid]
        active_sessions = get_active_sessions()
        socketio.emit('sessions_update', {'sessions': active_sessions})

@socketio.on('register_session')
def handle_register_session(data):
    session_id = data.get('session_id', '')
    if session_id:
        websocket_sessions[request.sid] = session_id
        active_sessions = get_active_sessions()
        socketio.emit('sessions_update', {'sessions': active_sessions})

@socketio.on('heartbeat')
def handle_heartbeat(data):
    session_id = data.get('session_id', '')
    if session_id:
        if r:
            session_data = r.get(f"session:{session_id}")
            if session_data:
                data = json.loads(session_data)
                data['timestamp'] = time.time()
                r.setex(f"session:{session_id}", 300, json.dumps(data))
        else:
            if session_id in sessions:
                sessions[session_id]['timestamp'] = time.time()
        socketio.emit('heartbeat_ack', {'status': 'ok'}, room=request.sid)

if __name__ == '__main__':
    print(f"Starting IP Tracker on /{SECRET_PATH}/")
    socketio.run(app, host='0.0.0.0', port=8800, debug=False, allow_unsafe_werkzeug=True)
EOF

# Create templates
mkdir -p templates
cat > templates/base.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Real-time IP Tracker for ES Sharing</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/socket.io/4.0.1/socket.io.js"></script>
</head>
<body>
    <div class="container mt-4">
        <h1 class="text-center mb-4">Real-time IP Tracker for ES Sharing</h1>
        {% block content %}{% endblock %}
    </div>
</body>
</html>
EOF

cat > templates/index.html << 'EOF'
{% extends "base.html" %}
{% block content %}
<div class="row">
    <div class="col-md-4">
        <div class="card">
            <div class="card-header"><h5>QR Code - Scan to Access</h5></div>
            <div class="card-body text-center">
                <img src="/{{ secret_path }}/qr-code" alt="QR Code" class="img-fluid" style="max-width: 200px;">
                <p class="mt-2 small">{{ website_url }}</p>
            </div>
        </div>
        <div class="card mt-3">
            <div class="card-header"><h5>Your Connection</h5></div>
            <div class="card-body">
                <strong>Your IP:</strong> {{ current_ip }}<br>
                <strong>Status:</strong> <span class="badge bg-success">Connected</span>
            </div>
        </div>
    </div>
    <div class="col-md-8">
        <div class="card">
            <div class="card-header d-flex justify-content-between">
                <h5>Connected Users</h5>
                <span class="badge bg-primary" id="connection-count">0</span>
            </div>
            <div class="card-body">
                <div class="table-responsive">
                    <table class="table table-striped">
                        <thead>
                            <tr>
                                <th>IP Address</th>
                                <th>Browser</th>
                                <th>OS</th>
                                <th>Duration</th>
                                <th>Instance</th>
                                <th>Status</th>
                            </tr>
                        </thead>
                        <tbody id="sessions-table"></tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<script>
const socket = io({path: '/{{ secret_path }}/socket.io'});
const sessionId = '{{ session_id }}';
let durationInterval;

socket.on('connect', function() {
    console.log('Connected to server');
    socket.emit('register_session', {session_id: sessionId});
    setInterval(() => {
        socket.emit('heartbeat', {session_id: sessionId});
    }, 30000);
    startDurationUpdater();
});

socket.on('disconnect', function() {
    stopDurationUpdater();
});

function startDurationUpdater() {
    durationInterval = setInterval(() => {
        updateDurations();
    }, 1000);
}

function stopDurationUpdater() {
    if (durationInterval) {
        clearInterval(durationInterval);
    }
}

function formatDuration(seconds) {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    if (hours > 0) {
        return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    return `${minutes}:${secs.toString().padStart(2, '0')}`;
}

function updateDurations() {
    document.querySelectorAll('.duration-cell').forEach(cell => {
        const startTime = parseFloat(cell.dataset.start);
        const duration = Math.floor((Date.now() / 1000) - startTime);
        cell.textContent = formatDuration(duration);
    });
}

socket.on('sessions_update', function(data) {
    const tbody = document.getElementById('sessions-table');
    const countBadge = document.getElementById('connection-count');
    tbody.innerHTML = '';
    countBadge.textContent = data.sessions.length;
    
    data.sessions.forEach(session => {
        const row = tbody.insertRow();
        const isCurrentUser = session.id === sessionId;
        if (isCurrentUser) row.classList.add('table-warning');
        
        const startTime = session.start_time || session.timestamp;
        const duration = Math.floor((Date.now() / 1000) - startTime);
        const durationStr = formatDuration(duration);
        
        row.innerHTML = `
            <td>${session.ip} ${isCurrentUser ? '<span class="badge bg-warning">You</span>' : ''}</td>
            <td>${session.headers?.browser || 'Unknown'}</td>
            <td>${session.headers?.os || 'Unknown'}</td>
            <td class="duration-cell" data-start="${startTime}">${durationStr}</td>
            <td><span class="badge bg-info">${session.instance_id || 'unknown'}</span></td>
            <td><span class="badge bg-success">Online</span></td>
        `;
    });
});

window.addEventListener('beforeunload', function() {
    socket.disconnect();
});
</script>
{% endblock %}
EOF

cat > templates/error.html << 'EOF'
{% extends "base.html" %}
{% block content %}
<div class="row justify-content-center">
    <div class="col-md-6">
        <div class="card">
            <div class="card-header bg-danger text-white">
                <h5>Maximum Users Reached</h5>
            </div>
            <div class="card-body text-center">
                <h1 class="display-1">🚫</h1>
                <h3>Sorry!</h3>
                <p>Maximum 3 users reached. Try again later.</p>
                <button class="btn btn-primary" onclick="location.reload()">Try Again</button>
            </div>
        </div>
    </div>
</div>
{% endblock %}
EOF

# Set environment variables
echo "export REDIS_HOST=$REDIS_HOST" >> /etc/environment
echo "export SECRET_PATH=$SECRET_PATH" >> /etc/environment

# Create systemd service
cat > /etc/systemd/system/ip-tracker.service << EOF
[Unit]
Description=IP Tracker Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/ip-tracker
ExecStart=/usr/bin/python3 app.py
Restart=always
RestartSec=10
Environment=REDIS_HOST=$REDIS_HOST
Environment=SECRET_PATH=$SECRET_PATH

[Install]
WantedBy=multi-user.target
EOF

# Start service
systemctl enable ip-tracker
systemctl daemon-reload
systemctl start ip-tracker

# Configure CloudWatch Logs Agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWEOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/ec2/ip-tracker/system",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "IPTracker",
    "metrics_collected": {
      "mem": {
        "measurement": [
          {"name": "mem_used_percent", "rename": "MemoryUsed", "unit": "Percent"}
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
CWEOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

sleep 10
systemctl status ip-tracker