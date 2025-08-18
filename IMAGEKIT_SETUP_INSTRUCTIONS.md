# ImageKit Setup Instructions

## 🔑 **Required Credentials**

To fix the ImageKit authentication errors (503 status), you need to get your credentials from the ImageKit dashboard:

### **1. Get Your ImageKit Credentials**
1. Go to [https://imagekit.io/dashboard/developer/api-keys](https://imagekit.io/dashboard/developer/api-keys)
2. Sign up/login to your ImageKit account
3. Copy your credentials:
   - **Public Key** (already configured: `public_tAO0SkfLl/37FQN+23c/bkAyfYg=`)
   - **Private Key** (you need to get this)
   - **URL Endpoint** (already configured: `https://ik.imagekit.io/tkhb6zllk`)

### **2. Update Configuration Files**

#### **Option A: Update Environment Variables (Recommended)**
Create a `.env` file in your project root with:
```bash
IMAGEKIT_PUBLIC_KEY=public_tAO0SkfLl/37FQN+23c/bkAyfYg=
IMAGEKIT_PRIVATE_KEY=your_actual_private_key_here
IMAGEKIT_URL_ENDPOINT=https://ik.imagekit.io/tkhb6zllk
PORT=3001
```

#### **Option B: Update Code Directly**
Update `admin_dashboard/lib/config/imagekit_config.dart`:
```dart
static const String privateKey = 'your_actual_private_key_here';
```

### **3. Test the Configuration**

#### **Start Local Authentication Server**
```bash
cd /c/food_marketplace_app
npm install  # Install dependencies if not already done
node server.js  # Start the authentication server
```

#### **Verify Authentication Endpoint**
Visit: `http://localhost:3001/auth`
Should return: `{"token": "...", "signature": "...", "expire": "..."}`

## 🚨 **Current Issues**

1. **503 Authentication Errors**: The remote auth server is failing
2. **Missing Private Key**: Your private key needs to be configured
3. **Local Server Not Running**: The local authentication server needs to be started

## ✅ **Expected Results After Setup**

- Image uploads should work without 503 errors
- Seller registration image uploads should succeed
- Profile image uploads should work
- Product image uploads should work

## 🔧 **Alternative Solutions**

### **Option 1: Use Local Authentication Server**
- Start `server.js` locally
- Update app to use `http://localhost:3001/auth` instead of remote server

### **Option 2: Fix Remote Server**
- The server at `https://imagekit-auth-server-f4te.onrender.com/auth` needs proper configuration
- Contact the server administrator or redeploy with correct credentials

### **Option 3: Direct ImageKit Integration**
- Use ImageKit SDK directly in Flutter (requires additional setup)

## 📱 **Testing Steps**

1. **Configure credentials** (see steps above)
2. **Start local server**: `node server.js`
3. **Test image upload** in seller registration
4. **Verify no more 503 errors** in console

## 🆘 **Need Help?**

If you don't have ImageKit credentials:
1. Sign up at [https://imagekit.io](https://imagekit.io)
2. Create a new project
3. Get your API keys from the dashboard
4. Follow the setup steps above

The app is already configured to use ImageKit - you just need the proper credentials!
