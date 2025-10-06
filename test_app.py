#!/usr/bin/env python3
"""Simple test script for the IP tracker application"""

import sys
import time
from app.session import *
from app.utils import detect_browser_os
from app.security import sanitize_headers, check_rate_limit, validate_input
from app.qr_generator import generate_qr_code

def test_session_management():
    """Test session CRUD operations"""
    print("Testing session management...")
    
    # Test add session
    session_id = add_session("192.168.1.1", "Mozilla/5.0", {"test": "data"})
    assert session_id is not None
    print(f"✓ Session created: {session_id}")
    
    # Test get sessions
    sessions = get_active_sessions()
    assert len(sessions) == 1
    print(f"✓ Active sessions: {len(sessions)}")
    
    # Test connection count
    count = get_connection_count()
    assert count == 1
    print(f"✓ Connection count: {count}")
    
    # Test remove session
    removed = remove_session(session_id)
    assert removed == True
    print("✓ Session removed")
    
    print("Session management tests passed!\n")

def test_browser_detection():
    """Test browser and OS detection"""
    print("Testing browser/OS detection...")
    
    test_agents = [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    ]
    
    for agent in test_agents:
        result = detect_browser_os(agent)
        print(f"✓ {result['browser']} on {result['os']}")
    
    print("Browser detection tests passed!\n")

def test_security():
    """Test security functions"""
    print("Testing security functions...")
    
    # Test input sanitization
    malicious_input = "<script>alert('xss')</script>"
    sanitized = validate_input(malicious_input)
    assert "<script>" not in sanitized
    print("✓ XSS prevention works")
    
    # Test rate limiting
    ip = "192.168.1.100"
    for i in range(5):
        result = check_rate_limit(ip, limit=3)
        if i < 3:
            assert result == True
        else:
            assert result == False
    print("✓ Rate limiting works")
    
    print("Security tests passed!\n")

def test_qr_generation():
    """Test QR code generation"""
    print("Testing QR code generation...")
    
    url = "http://example.com:8800"
    qr_data = generate_qr_code(url)
    assert qr_data.startswith("data:image/png;base64,")
    print("✓ QR code generated successfully")
    
    print("QR generation tests passed!\n")

if __name__ == "__main__":
    print("Running IP Tracker Application Tests\n")
    
    try:
        test_session_management()
        test_browser_detection()
        test_security()
        test_qr_generation()
        
        print("🎉 All tests passed!")
        
    except Exception as e:
        print(f"❌ Test failed: {e}")
        sys.exit(1)