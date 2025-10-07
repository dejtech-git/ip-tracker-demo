from flask import Flask, render_template, request, abort
from flask_socketio import SocketIO, emit
import threading
import time
import os
from app.redis_session import *
from app.utils import get_client_ip, extract_headers, detect_browser_os, get_instance_id
from app.qr_generator import generate_qr_code
from app.security import sanitize_headers, check_rate_limit, validate_input

app = Flask(__name__)
app.config['SECRET_KEY'] = 'dev-secret-key'
socketio = SocketIO(app, cors_allowed_origins="*", path=f'/{SECRET_PATH}/socket.io')

# Get secret path from environment
SECRET_PATH = os.environ.get('SECRET_PATH', 'app-x7k9m2n8')

# Store WebSocket session mapping
websocket_sessions = {}

@app.route(f'/{SECRET_PATH}/')
@app.route(f'/{SECRET_PATH}')
@app.route('/')
def index():
    """Main page route"""
    ip = get_client_ip()
    
    # More lenient rate limiting for testing (20 requests per minute)
    if not check_rate_limit(ip, limit=20, window=60):
        print(f"Rate limit exceeded for IP: {ip}")
        return render_template('error.html'), 429
    
    # Check instance capacity with configurable limit
    max_users = int(os.environ.get('MAX_USERS_PER_INSTANCE', 25))
    if get_instance_connection_count() >= max_users:
        return render_template('error.html'), 503
    
    headers = extract_headers()
    browser_info = detect_browser_os(headers['user_agent'])
    sanitized_headers = sanitize_headers(headers)
    
    # Create session
    instance_id = get_instance_id()
    session_id = add_session(ip, sanitized_headers['user_agent'], {**sanitized_headers, **browser_info}, instance_id)
    
    # Get current URL for QR code
    base_url = request.url_root.rstrip('/') + f'/{SECRET_PATH}/'
    
    print(f"New session created: {session_id} for IP: {ip}")
    
    # Generate QR code data URL for template
    qr_data_url = generate_qr_code(base_url)
    
    return render_template('index.html', 
                         session_id=session_id,
                         current_ip=ip,
                         website_url=base_url,
                         secret_path=SECRET_PATH,
                         qr_code_data=qr_data_url)

@app.route('/health')
def health():
    """Health check endpoint"""
    return {'status': 'healthy', 'connections': get_instance_connection_count(), 'total_connections': get_total_connection_count()}

@app.route(f'/{SECRET_PATH}/qr-code')
@app.route('/qr-code')
def qr_code():
    """Generate QR code for current URL"""
    base_url = request.url_root.rstrip('/') + f'/{SECRET_PATH}/'
    qr_data_url = generate_qr_code(base_url)
    
    # Extract base64 data and return as PNG
    import base64
    base64_data = qr_data_url.split(',')[1]
    img_data = base64.b64decode(base64_data)
    
    return img_data, 200, {'Content-Type': 'image/png'}

@socketio.on('connect')
def handle_connect():
    """Handle WebSocket connection"""
    print(f'Client connected: {request.sid}')

@socketio.on('disconnect')
def handle_disconnect():
    """Handle WebSocket disconnection"""
    if request.sid in websocket_sessions:
        session_id = websocket_sessions[request.sid]
        remove_session(session_id)
        del websocket_sessions[request.sid]
        broadcast_sessions()
    print(f'Client disconnected: {request.sid}')

@socketio.on('cleanup_old_session')
def handle_cleanup_old_session(data):
    """Cleanup old session from browser refresh"""
    old_session_id = data.get('old_session_id')
    if old_session_id:
        print(f"Cleaning up old session: {old_session_id}")
        remove_session(old_session_id)
        # Remove from websocket mapping if exists
        for ws_sid, sess_id in list(websocket_sessions.items()):
            if sess_id == old_session_id:
                del websocket_sessions[ws_sid]
                break
        broadcast_sessions()

@socketio.on('register_session')
def handle_register_session(data):
    """Register session with WebSocket"""
    session_id = validate_input(data.get('session_id', ''), 50)
    if session_id:
        websocket_sessions[request.sid] = session_id
        broadcast_sessions()

@socketio.on('heartbeat')
def handle_heartbeat(data):
    """Handle heartbeat from client"""
    session_id = validate_input(data.get('session_id', ''), 50)
    if session_id and update_session_timestamp(session_id):
        emit('heartbeat_ack', {'status': 'ok'})

def broadcast_sessions():
    """Broadcast current sessions to all clients"""
    active_sessions = get_active_sessions()
    # Format sessions for frontend
    formatted_sessions = []
    for session in active_sessions:
        formatted_sessions.append({
            'id': session.get('session_id', session.get('ip', 'unknown')),
            'ip': session['ip'],
            'headers': session.get('metadata', session.get('headers', {})),
            'timestamp': session.get('timestamp', session.get('start_time', 0)),
            'instance_id': session.get('instance_id', 'unknown')
        })
    socketio.emit('sessions_update', {'sessions': formatted_sessions})

def cleanup_thread():
    """Background thread for session cleanup"""
    while True:
        expired = cleanup_expired_sessions()
        if expired:
            print(f"Cleaned up {len(expired)} expired sessions")
            broadcast_sessions()
        time.sleep(30)

if __name__ == '__main__':
    # Start cleanup thread
    cleanup_worker = threading.Thread(target=cleanup_thread, daemon=True)
    cleanup_worker.start()
    
    print("Starting Real-time IP Tracker for ES Sharing on http://localhost:8800")
    socketio.run(app, host='0.0.0.0', port=8800, debug=False, allow_unsafe_werkzeug=True)