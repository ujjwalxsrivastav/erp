#!/bin/bash

# Flutter Web Build and Deploy Script for Firebase Hosting with Supabase
# This script builds your Flutter web app with Supabase credentials and deploys it

echo "🚀 Starting Flutter Web Build & Deploy Process..."
echo ""

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "❌ Error: .env file not found!"
    echo "Please create a .env file with your Supabase credentials"
    exit 1
fi

# Load environment variables from .env
export $(cat .env | grep -v '^#' | xargs)

# Check if credentials are set
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
    echo "❌ Error: SUPABASE_URL or SUPABASE_ANON_KEY not set in .env file"
    exit 1
fi

echo "✅ Supabase credentials loaded"
echo ""

# Step 1: Clean previous builds
echo "📦 Cleaning previous builds..."
flutter clean
echo "✅ Clean complete"
echo ""

# Step 2: Get dependencies
echo "📥 Getting dependencies..."
flutter pub get
echo "✅ Dependencies fetched"
echo ""

# Step 3: Build for web with environment variables
echo "🔨 Building Flutter web app (release mode with Supabase credentials)..."
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build complete"
echo ""

# Step 4: Deploy to Firebase
echo "🚀 Deploying to Firebase Hosting..."
firebase deploy --only hosting

if [ $? -ne 0 ]; then
    echo "❌ Deployment failed!"
    exit 1
fi

echo ""
echo "✅ Deployment complete!"
echo "🌐 Your app is now live!"
echo ""
echo "To view your app, check the URL shown above or visit:"
echo "https://console.firebase.google.com"
