# Firebase Hosting - ERP System Deployment Guide

## 🚀 Quick Setup (5 Minutes)

### Step 1: Install Firebase CLI
```bash
npm install -g firebase-tools
```

### Step 2: Login to Firebase
```bash
firebase login
```
This will open your browser - login with your Google account.

### Step 3: Initialize Firebase (One-time setup)
```bash
cd /Users/centerofbusinessincubationandinnovationcbii/Desktop/erp
firebase init hosting
```

**During setup, answer:**
- **What do you want to use as your public directory?** → `build/web`
- **Configure as a single-page app?** → `Yes`
- **Set up automatic builds with GitHub?** → `No` (for now)
- **Overwrite build/web/index.html?** → `No`

### Step 4: Build Flutter Web
```bash
flutter build web --release
```

### Step 5: Deploy to Firebase
```bash
firebase deploy --only hosting
```

**Done! 🎉** Your app will be live at: `https://your-project-id.web.app`

---

## 📝 Daily Deployment Workflow

After initial setup, deploying updates is just 2 commands:

```bash
# 1. Build the app
flutter build web --release

# 2. Deploy
firebase deploy --only hosting
```

---

## 🔧 Advanced Configuration

### Custom Domain Setup
1. Go to Firebase Console → Hosting
2. Click "Add custom domain"
3. Follow the DNS configuration steps
4. SSL certificate is automatic!

### Preview Before Deploy
```bash
firebase hosting:channel:deploy preview
```

### View Deployment History
```bash
firebase hosting:clone your-project-id:live preview
```

---

## 🐛 Troubleshooting

### Build fails?
```bash
flutter clean
flutter pub get
flutter build web --release
```

### Firebase CLI not found?
```bash
npm install -g firebase-tools
```

### Login issues?
```bash
firebase logout
firebase login --reauth
```

---

## 📊 What Gets Deployed

- **Source**: `build/web/` directory
- **Size**: ~10-20 MB (optimized)
- **Files**: HTML, CSS, JS, Assets
- **CDN**: Automatic global distribution
- **SSL**: Free HTTPS certificate

---

## 🎯 Performance Tips

1. **Enable Caching** (already configured in firebase.json)
2. **Use CanvasKit renderer** for better performance:
   ```bash
   flutter build web --web-renderer canvaskit
   ```
3. **Compress assets** before building
4. **Monitor with Firebase Analytics**

---

## 🔐 Security

- Firebase Hosting includes DDoS protection
- Automatic SSL/TLS certificates
- Secure by default
- No server management needed

---

## 💰 Pricing

**Free Tier (Spark Plan):**
- 10 GB storage
- 360 MB/day bandwidth
- Custom domain support
- SSL included

**Perfect for your ERP system!** 🎉

---

## 📱 Testing Locally

Before deploying, test locally:
```bash
flutter build web
firebase serve --only hosting
```
Visit: `http://localhost:5000`

---

## 🚀 CI/CD (Optional - GitHub Actions)

Create `.github/workflows/deploy.yml`:
```yaml
name: Deploy to Firebase

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter build web --release
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          channelId: live
```

---

## 📞 Support

- Firebase Console: https://console.firebase.google.com
- Documentation: https://firebase.google.com/docs/hosting
- Status: https://status.firebase.google.com

---

**Happy Deploying! 🚀**
