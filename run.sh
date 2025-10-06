#!/bin/bash
# Simple script to run the IP tracker application

echo "Starting Real-time IP Tracker Application..."
echo "Application will be available at: http://localhost:8800"
echo "Press Ctrl+C to stop the server"
echo ""

# Activate virtual environment and run the app
source venv/bin/activate
python app.py